<?php

return [
    // The bucket where the application archive is stored
    $awsS3Bucket = '',

    $awsRegion = '',

    $awsVersion = 'latest',

    // The application name as defined in Codedeploy configuration, usually follows the name of the repository
    $applicationName = '',

    // Deployment groups are named after the ec2 tags used to identify the different machines target of the deploys
    $deploymentGroups = [
    ],
];
