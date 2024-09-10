# Steps for building Pravega Zookeeper on s390x

#### Note: The below steps have been validated on RHEL 8.
   
1. Install required Pre-reqs
    1. Go 1.17+ 
    2. Docker 
    3. helm
    4. make
    5. git

    Use below commands to install pre-reqs

    ```
    yum install -y go docker make git
    ```

    ```
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    ```

1. Clone the git repo using following command
    ```
     git clone https://github.com/pravega/zookeeper-operator.git
     cd zookeeper-operator
    ```

2. Apply the patch file after copying the below contents to `zk.patch`

    ```
    diff --git a/Dockerfile b/Dockerfile
    index b5813dd..01b1ce5 100644
    --- a/Dockerfile
    +++ b/Dockerfile
    @@ -26,7 +26,7 @@ COPY api/ api/
     COPY controllers/ controllers/
 
     # Build
    -RUN GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o /src/${PROJECT_NAME} \
    +RUN GOOS=linux GOARCH=s390x CGO_ENABLED=0 go build -o /src/${PROJECT_NAME} \
         -ldflags "-X ${REPO_PATH}/pkg/version.Version=${VERSION} -X ${REPO_PATH}/pkg/version.GitSHA=${GIT_SHA}" main.go
 
     FROM ${DISTROLESS_DOCKER_REGISTRY:-gcr.io/}distroless/static-debian11:nonroot AS final
    diff --git a/Makefile b/Makefile
    index 0017afb..9f27729 100644
    --- a/Makefile
    +++ b/Makefile
    @@ -128,6 +128,12 @@ build-go:
            CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build \
                    -ldflags "-X github.com/$(REPO)/pkg/version.Version=$(VERSION) -X github.com/$(REPO)/pkg/version.GitSHA=$(GIT_SHA)" \
                    -o bin/$(EXPORTER_NAME)-windows-amd64.exe cmd/exporter/main.go
    +       CGO_ENABLED=0 GOOS=linux GOARCH=s390x go build \
    +                -ldflags "-X github.com/$(REPO)/pkg/version.Version=$(VERSION) -X github.com/$(REPO)/pkg/version.GitSHA=$(GIT_SHA)" \
    +                -o bin/$(PROJECT_NAME)-linux-s390x main.go
    +       CGO_ENABLED=0 GOOS=linux GOARCH=s390x go build \
    +                -ldflags "-X github.com/$(REPO)/pkg/version.Version=$(VERSION) -X github.com/$(REPO)/pkg/version.GitSHA=$(GIT_SHA)" \
    +                -o bin/$(EXPORTER_NAME)-linux-s390x cmd/exporter/main.go
 
     build-image:
            docker build --build-arg VERSION=$(VERSION) --build-arg DOCKER_REGISTRY=$(DOCKER_REGISTRY) --build-arg DISTROLESS_DOCKER_REGISTRY=$(DISTROLESS_DOCKER_REGISTRY) --build-arg         GIT_SHA=$(GIT_SHA) -t $(REPO):$(VERSION) .
    diff --git a/docker/Dockerfile b/docker/Dockerfile
    index 368f7a9..0f7cde3 100644
    --- a/docker/Dockerfile
    +++ b/docker/Dockerfile
    @@ -9,7 +9,7 @@
     #
 
     ARG DOCKER_REGISTRY
    -FROM  ${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}openjdk:11-jdk
    +FROM  ${DOCKER_REGISTRY:+$DOCKER_REGISTRY/}ibmjava:11-jdk
     RUN mkdir /zu
     COPY zu /zu
     WORKDIR /zu
    ```

3.	Apply the `zk.patch` using the following:

    ```
  	git apply --ignore-space-change --ignore-whitespace zk.patch
    ```

4.	Build the zookeeper-operator image with following command:

    ```
  	make build
    ```
    > Note: Select the base image from the docker.io registry

    This will generate zookeeper operator Docker image as below:
  	
     ```
     $ docker images
     pravega/zookeeper-operator  latest           07a40cc2371c  3 days ago    58.7 MB
     pravega/zookeeper-operator  0.2.15-10-dirty  07a40cc2371c  3 days ago    58.7 MB
     ```

   
    ```
  	make build-zk-image
    ```
    > Note: Select the base image from the docker.io registry

  	This will generate zookeeper operand Docker image as below:

     ```
     $ docker images
     pravega/zookeeper           0.2.15-10-dirty  dd8504c2a4f6  3 days ago    375 MB
     pravega/zookeeper           latest           dd8504c2a4f6  3 days ago    375 MB
     ```
     
5. Push the images to a Docker registry.

    ```
    docker tag pravega/zookeeper-operator [REGISTRY_HOST]:[REGISTRY_PORT]/pravega/zookeeper-operator
    docker push [REGISTRY_HOST]:[REGISTRY_PORT]/pravega/zookeeper-operator    

    docker tag pravega/zookeeper [REGISTRY_HOST]:[REGISTRY_PORT]/pravega/zookeeper
    docker push [REGISTRY_HOST]:[REGISTRY_PORT]/pravega/zookeeper
    ```
    
    where:
    
    - `[REGISTRY_HOST]` is your registry host or IP (e.g. `registry.example.com`)
    - `[REGISTRY_PORT]` is your registry port (e.g. `5000`)


6.	Complete below steps to deploy zookeeper operator. Make sure you have default storage class configured in your cluster.

    1. Create the `zookeeper` namespace.
  	```
    kubectl create ns zookeeper
    ```
    2. Create image pull secrets to your docker registry.
  	```
    kubectl create secret docker-registry zookeeper-registry --namespace zookeeper \
        --docker-username=<user_name> \
        --docker-password=<password> \
        --docker-server=<docker_registry>
    ```
    3. Install the Zookeeper operator.
  	
    ```
    helm repo add pravega https://charts.pravega.io
    helm repo update
    helm install zookeeper-operator  pravega/zookeeper-operator --version=0.2.15 --set image.repository=<image_name> --set image.tag=<image_tag> --set global.imagePullSecrets[0]=zookeeper-registry --no-hooks -n zookeeper
    ```
8. Verify the operator pods is up and running
   ```
     oc get all -n zookeeper
   ```
   ```
    zookeeper-operator-58796b8869-g7mtw   1/1     Running   0          17h
   ```
9. To deploy zookeeper instance, create `zk.yaml` with following content:
    ```
    apiVersion: "zookeeper.pravega.io/v1beta1"
    kind: "ZookeeperCluster"
    metadata:
      name: "zookeeper"
    spec:
      replicas: 3
      image:
        repository: "<image_name>"
        tag: "<image_tag>"
        pullPolicy: "Always"
    ```
    > Note: If you want to configure zookeeper pod, for example to change the service account or the CPU limits, you can set the following properties:                                 [~/charts/zookeeper/templates/zookeeper.yaml](https://github.com/pravega/zookeeper-operator/blob/master/charts/zookeeper/templates/zookeeper.yaml).

   ```
    apiVersion: "zookeeper.pravega.io/v1beta1"
    kind: "ZookeeperCluster"
    metadata:
      name: "zookeeper"
    spec:
      replicas: 3
      image:
        repository: "<image_name>"
        tag: "<image_tag>"
        pullPolicy: "Always"
      pod:
        serviceAccountName: "zookeeper"
        resources:
            requests:
              cpu: 200m
              memory: 256Mi
            limits:
              cpu: 200m
              memory: 256Mi
    ```

10. Verify the deployment status

    ```
     oc get all -n zookeeper
    ```

    ```      
      NAME                                      READY   STATUS    RESTARTS      AGE
      pod/zookeeper-0                           1/1     Running      0          17h
      pod/zookeeper-1                           1/1     Running      0          17h
      pod/zookeeper-2                           1/1     Running      0          17h
      pod/zookeeper-operator-58796b8869-g7mtw   1/1     Running      0          17h
      
      NAME                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                        AGE
      service/zookeeper-admin-server   ClusterIP   172.30.91.153   <none>        8080/TCP                                       17h
      service/zookeeper-client         ClusterIP   172.30.60.72    <none>        2181/TCP                                       17h
      service/zookeeper-headless       ClusterIP   None            <none>        2181/TCP,2888/TCP,3888/TCP,7000/TCP,8080/TCP   17h
      
      NAME                                 READY   UP-TO-DATE   AVAILABLE       AGE
      deployment.apps/zookeeper-operator    1/1        1            1           17h
      
      NAME                                            DESIRED   CURRENT   READY     AGE
      replicaset.apps/zookeeper-operator-58796b8869      1         1        1       17h
      
      NAME                         READY   AGE
      statefulset.apps/zookeeper   3/3     17h

    ```


 
