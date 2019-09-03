<?php

namespace Codedeployer;

use Throwable;
use Aws\CodeDeploy\CodeDeployClient;
use Aws\S3\S3Client;

class Deploy
{
    public function run($rootDir)
    {
        $config = require $rootDir . '/deploy/config.php';

        $exitCode = 1;

        try {
            if (empty($config['applicationName'])) {
                throw new \Exception('Application name is missing, add to config.php');
            }

            if (empty($config['applicationName'])) {
                throw new \Exception('Deployment groups not configured, add to config.php');
            }

            /*
             * Get current git commit hash and save it to file
             */
            $revision = trim(shell_exec("git rev-parse --short HEAD"));
            $timestampedRevision = date('Ymd_His') . "_{$revision}";
            shell_exec("echo {$timestampedRevision} > {$rootDir}/deploy/deployed_revision");

            $archiveName = "{$revision}.tgz";

            $s3Client = new S3Client([
                'region'  => $config['awsRegion'],
                'version' => $config['awsVersion'],
            ]);

            $codedeployClient = new CodeDeployClient([
                'region'  => $config['awsRegion'],
                'version' => $config['awsVersion'],
            ]);

            /*
             * Create the application archive with the required appspec.yml file needed for the deployment
             */
            exec("cp {$rootDir}/deploy/appspec.yml {$rootDir}");
            exec("cd {$rootDir} && touch {$archiveName} && tar --exclude {$archiveName} --exclude-vcs -zcf {$archiveName} .");

            /*
             * Send the archive to the S3 bucket
             */
            $s3Client->putObject([
                'Bucket'     => $config['awsS3Bucket'],
                'Key'        => "{$config['applicationName']}/{$archiveName}",
                'SourceFile' => "{$rootDir}/{$archiveName}",
            ]);

            $deploymentIds = [];

            /*
             * Start deployment for every configured deployed group in the current application
             */
            foreach ($config['applicationName'] as $deploymentGroup) {
                $deploymentResult = $codedeployClient->createDeployment([
                    'applicationName'     => $config['applicationName'],
                    'deploymentGroupName' => $deploymentGroup,
                    'revision'            => [
                        'revisionType' => 'S3',
                        's3Location'   => [
                            'bucket'     => $config['awsS3Bucket'],
                            'key'        => "{$config['applicationName']}/{$archiveName}",
                            'bundleType' => 'tgz',
                        ]
                    ],
                ]);

                echo "Deploying {$deploymentGroup} id: {$deploymentResult->get('deploymentId')}\n";
                $deploymentIds[] = $deploymentResult->get('deploymentId');
            }

            $deploymentsStatus = [];

            /*
             * Poll deployment API to get the status of all running deployments waiting for completeTime to not be null.
             * When completeTime is not null for every deployment, the whole process ends.
             *
             * Deployment status can be Created|Queued|InProgress|Succeeded|Failed|Stopped|Ready
             */
            while (true) {
                foreach ($deploymentIds as $deploymentId) {
                    $deployment = $codedeployClient->getDeployment([
                        'deploymentId' => $deploymentId,
                    ]);

                    $deploymentInfo = $deployment->get('deploymentInfo');

                    $deploymentsStatus[$deploymentInfo['deploymentGroupName']] = [
                        'status'       => $deploymentInfo['status'],
                        'completeTime' => $deploymentInfo['completeTime'] ?? null,
                    ];
                }

                if (!array_filter($deploymentsStatus, function ($value) { return is_null($value['completeTime']); })) {
                    break;
                }

                echo '.';

                sleep(1);
            }

            echo "\n";
            $failed = false;

            foreach ($deploymentsStatus as $group => $status) {
                echo "{$group} {$status['status']} at {$status['completeTime']}\n";
                if ($status['status'] !== 'Succeeded') {
                    $failed = true;
                }
            }

            if (!$failed) {
                $exitCode = 0;
            }
        } catch (Throwable $e) {
            echo $e->getMessage(), "\n";
            exit(1);
        } finally {
            /*
             * Cleanup and exit with shell-compatible exit code so that the CI service can correctly display success/failure
             */
            if (!empty($archiveName)) {
                unlink("{$rootDir}/appspec.yml");
                unlink("{$rootDir}/deploy/deployed_revision");
                unlink("{$rootDir}/{$archiveName}");
            }

            exit($exitCode);
        }

    }
}
