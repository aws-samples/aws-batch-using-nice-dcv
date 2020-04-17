## Run 3D interactive applications with NICE DCV in AWS Batch

This repository includes dockerfiles and scripts to integrate and run NICE DCV with AWS Batch

More info on 
NICE DCV: https://docs.aws.amazon.com/dcv/
AWS Batch: https://aws.amazon.com/batch/

**NICE DCV** is a remote visualization technology that enables users to securely connect to graphic-intensive 3D applications hosted on a remote, high-performance server. With NICE DCV, you can make a server's high-performance graphics processing capabilities available to multiple remote users by creating secure client sessions.

**AWS Batch** enables developers, scientists, and engineers to easily and efficiently run hundreds of thousands of batch computing jobs on AWS. AWS Batch dynamically provisions the optimal quantity and type of compute resources (e.g., CPU or memory optimized instances) based on the volume and specific resource requirements of the batch jobs submitted. With AWS Batch, there is no need to install and manage batch computing software or server clusters that you use to run your jobs, allowing you to focus on analyzing results and solving problems. AWS Batch plans, schedules, and executes your batch computing workloads across the full range of AWS compute services and features, such as *Amazon EC2* (https://aws.amazon.com/ec2/) and *Spot Instances* (https://aws.amazon.com/ec2/spot/).

With this integration, multiple users can schedule interactive jobs via AWS Batch, connect to their interactive sessions via DCV protocol, run their favorite graphical applications efficiently and potentially with *OpenGL* acceleration, using either DCV web client (HTML5/h264) or the native one.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

