# Makefile for demo automation

# Container name
CONTAINER_NAME = simulator-cluster

# Color variables
COLOR_RED = \033[0;31m
COLOR_GREEN = \033[0;32m
COLOR_BLUE = \033[0;34m
COLOR_RESET = \033[0m

# Node memory parameter
NODE_MEMORY_PARAM = '.allocatable.memory=\"32Gi\"'

# Function to execute command inside the container
define exec_in_container
	echo "$(COLOR_BLUE)Executing in container: \"$(1)\"$(COLOR_RESET)"
	docker exec -it $(CONTAINER_NAME) sh -c "$(1)"
endef

# Enter container
.PHONY: enter-container
enter-container:
	docker exec -it $(CONTAINER_NAME) sh

# Copy YAML files into the container
.PHONY: copy-yaml-files
copy-yaml-files:
	docker cp backend-deployment.yaml $(CONTAINER_NAME):/root/
	docker cp low-priority-class.yaml $(CONTAINER_NAME):/root/
	docker cp low-priority-pods.yaml $(CONTAINER_NAME):/root/

# Scale out nodes to a specified number of replicas
.PHONY: scale-nodes
scale-nodes:
	@if [ -z "$(number)" ]; then \
		echo "$(COLOR_RED)Error: Please specify the number of replicas using 'number=<value>'$(COLOR_RESET)"; \
		exit 1; \
	fi
	echo "$(COLOR_GREEN)Scaling nodes to $(number) replicas...$(COLOR_RESET)"
	docker exec -it $(CONTAINER_NAME) sh -c "kwokctl scale node --replicas $(number) --param $(NODE_MEMORY_PARAM)"

# Deploy backend with a specified number of replicas
.PHONY: deploy-backend
deploy-backend:
	echo "$(COLOR_GREEN)Deploying backend...$(COLOR_RESET)"
	$(call exec_in_container, kwokctl kubectl apply -f /root/backend-deployment.yaml)

# Deploy low-priority-class and low-priority-pods with specified replicas
.PHONY: deploy-low-priority-class-and-pods
deploy-low-priority-class-and-pods:
	echo "$(COLOR_GREEN)Deploying low-priority class...$(COLOR_RESET)"
	$(call exec_in_container, kwokctl kubectl apply -f /root/low-priority-class.yaml)
	echo "$(COLOR_GREEN)Deploying low-priority pods...$(COLOR_RESET)"
	$(call exec_in_container, kwokctl kubectl apply -f /root/low-priority-pods.yaml)

# Observe low-priority pods (LPP) status
.PHONY: observe-lpp-status
observe-lpp-status:
	echo "$(COLOR_BLUE)Observing low-priority pods status...$(COLOR_RESET)"
	$(call exec_in_container, kwokctl kubectl get pods -o wide -l app=pause)

# Simulate Cluster Autoscaler: scale nodes to a specified number of replicas
.PHONY: scale-nodes-cluster-autoscaler
scale-nodes-cluster-autoscaler:
	@if [ -z "$(number)" ]; then \
		echo "$(COLOR_RED)Error: Please specify the number of replicas using 'number=<value>'$(COLOR_RESET)"; \
		exit 1; \
	fi
	echo "$(COLOR_GREEN)Scaling nodes to $(number) replicas...$(COLOR_RESET)"
	docker exec -it $(CONTAINER_NAME) sh -c "kwokctl scale node --replicas $(number) --param $(NODE_MEMORY_PARAM)"

# Simulate HPA: scale backend to specified replicas
.PHONY: scale-backend
scale-backend:
	echo "$(COLOR_GREEN)Scaling backend to $(replicas) replicas...$(COLOR_RESET)"
	$(call exec_in_container, kwokctl kubectl scale deploy/backend --replicas=$(replicas))

# Observe backend and low-priority pods status
.PHONY: observe-backend-status
observe-backend-status:
	echo "$(COLOR_BLUE)Observing backend deployment status...$(COLOR_RESET)"
	$(call exec_in_container, kwokctl kubectl get deploy)
	echo "$(COLOR_BLUE)Observing low-priority pods status...$(COLOR_RESET)"
	$(call exec_in_container, kwokctl kubectl get pods -o wide -l app=backend)

# Run all steps sequentially
.PHONY: run-demo
run-demo:
	@echo "Running the demo..."
	$(MAKE) copy-yaml-files
	$(MAKE) scale-nodes number=10
	$(MAKE) deploy-backend
	$(MAKE) deploy-low-priority-class-and-pods
	$(MAKE) observe-lpp-status
	$(MAKE) scale-nodes-cluster-autoscaler number=13
	$(MAKE) observe-lpp-status
	$(MAKE) scale-backend replicas=52
	$(MAKE) observe-backend-status

# List demo steps
.PHONY: list-demo
list-demo:
	@echo "Set up environments"
	@echo "Target: copy-yaml-files"
	@echo "Demo Steps:"
	@echo "1. Scale out Node → 10"
	@echo "   Target: scale-nodes number=10"
	@echo "2. Deploy Backend x 40"
	@echo "   Target: deploy-backend"
	@echo "3. Deploy low-priority-class and low-priority-pod x 12"
	@echo "   Target: deploy-low-priority-class-and-pods"
	@echo "4. Observe LPP Pending"
	@echo "   Target: observe-lpp-status"
	@echo "5. Simulate the behavior of clusterautoscaler: Scale out Node → 13"
	@echo "   Target: scale-nodes-cluster-autoscaler number=13"
	@echo "6. Observe LPP, it should be deployed to the Proactive Node"
	@echo "   Target: observe-lpp-status"
	@echo "7. Simulate the behavior of HPA: Scale out backend 40 → 52"
	@echo "   Target: scale-backend"
	@echo "8. Observe Backend preempt LPP"
	@echo "   Target: observe-backend-status"
