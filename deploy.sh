#!/bin/bash

#######################################################################
# Purpose : Build Docker Image, Push AWS ECR and deploy on ECS Cluster
# Maintainer: Tarikur Rahaman
# Create Date: 01-002-2016
# Last Modified Date: 24-07-2016
#######################################################################

# Docker ECS authorization token get for North virginia
# Run Below command:
# 
# $ aws ecr get-login --region us-east-1
#


# Remove old task defination 
if [  -f task_${TAG}.json ]; then
    rm task_${TAG}.json
fi

## Global Variable Section Start

TODAY=$(date +"_%d_%m")
LAST_COMMIT_ID=`git log | head -n 1 | awk '{print $2}' | cut -c1-8`
TAG="$LAST_COMMIT_ID$TODAY"
IMAGE_NAME="234464546150.dkr.ecr.us-east-1.amazonaws.com/chat-engine:$TAG"
SERVICE_NAME="chat-engine-service"
TASK_FAMILY="chat-engine-task"
CLUSTER_NAME="chat-engine-cluster"
REGION="us-east-1"

## Global Variable Section End

docker build -t $IMAGE_NAME . 
if [ $? -eq 0 ];then
    echo "---------------:::Docker Image build done Successfully:::---------------"
    docker push $IMAGE_NAME
fi

if [ $? -eq 0 ];then
    echo "---------------:::Docker Image Pushed Successfully AWS ECR:::---------------"
    else
    echo "---------------:::Docker Image Pushed Failed to AWS ECR:::---------------"
    exit 1
fi


# Create a new task definition for this build
sed -e "s;%BUILD_ID%;${TAG};g" task.json > task_${TAG}.json
aws ecs register-task-definition --region ${REGION} --family ${TASK_FAMILY} --cli-input-json file://task_${TAG}.json > /dev/null

# Update the service with the new task definition and desired count
TASK_REVISION=`aws ecs describe-task-definition --region ${REGION} --task-definition ${TASK_FAMILY} | egrep "revision" | tr "/" " " | awk '{print $2}' | sed 's/"$//'`
DESIRED_COUNT=`aws ecs describe-services --region ${REGION} --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} | egrep "desiredCount" | tr "/" " " | awk '{print $2}' | head -n 1| sed 's/,$//'`

if [ ${DESIRED_COUNT} = "0" ]; then
    DESIRED_COUNT="1"
fi

if [ "$?" -eq "0" ];then
    aws ecs update-service --cluster --region ${REGION} ${CLUSTER_NAME} --service ${SERVICE_NAME} --task-definition ${TASK_FAMILY}:${TASK_REVISION} --desired-count ${DESIRED_COUNT} > /dev/null
fi

if [ "$?" -eq "0" ];then
    echo
    echo "------------------:::Cluster Update Successfully::--::Need Some Moment to See the effect in Production (Typically 3 Min)::-------------------"
    echo
else
    echo
    echo "---------------:::Something Went Wrong. Please Verify Manually:::---------------"
    echo
fi
