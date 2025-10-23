# Ollama LLM Deployment Plan

**Date**: 2025-10-23
**Status**: Ready for implementation
**Priority**: HIGH (needed for all AI operations)

---

## Executive Summary

### Current State
- ✅ Ollama running in Kubernetes (talos-worker1)
- ✅ OpenWebUI accessible at https://ollama.mylegion5pro.me/
- ❌ **NO LLM MODELS RUNNING** (critical gap)

### What's Needed
Deploy LLM models on Ollama to power:
- Flowise AI agents
- n8n workflows
- Custom AI applications
- Local inference (no external API calls)

### Recommended Solution
**Activate talos-worker4 as dedicated LLM inference node**

---

## Why talos-worker4 is Critical

### Current Architecture Problem

```
Current (3 workers):
├─ talos-worker1: Ollama (no models) + system services
├─ talos-worker2: n8n, Flowise, databases
└─ talos-worker3: Databases, caching

Problems:
├─ Ollama competes with other services for resources
├─ LLM inference is CPU/GPU intensive
├─ No dedicated capacity for model serving
└─ Performance bottleneck for all AI operations
```

### Proposed Solution (with talos-worker4)

```
Proposed (4 workers):
├─ talos-worker1: System services + small models
├─ talos-worker2: n8n, Flowise workflows
├─ talos-worker3: Databases, caching, Redis
└─ talos-worker4: Dedicated LLM inference engine ⭐
                   └─ Large models (7B, 13B, 70B)
                   └─ Multi-model serving
                   └─ Fast inference
                   └─ No resource contention

Benefits:
✅ Dedicated inference capacity
✅ Better performance across all services
✅ Can handle multiple models
✅ No resource competition
✅ Scalable for future models
```

---

## Implementation Plan

### Phase 1: Activate talos-worker4 (5 minutes)

**Step 1: Start the VM**
```bash
ssh root@192.168.1.191
qm start 112
# Wait 2-3 minutes for Talos to boot and join cluster
```

**Step 2: Verify it joined the cluster**
```bash
kubectl get nodes
# Should show talos-worker4 as Ready
```

**Expected result**:
- 7 nodes in cluster (3 CP + 4 workers)
- talos-worker4 Ready and accepting workloads

---

### Phase 2: Verify Ollama is Ready (2 minutes)

**Check Ollama pod**
```bash
kubectl get pod -n default -l app=ollama -o wide
```

**Expected result**:
- Pod running on one of the worker nodes
- Status: 1/1 Running

---

### Phase 3: Pull LLM Models (depends on model size)

**Recommended Models** (in order of priority):

#### **Tier 1: Essential (2-7GB)**
```
1. mistral:latest (7B model)
   └─ Fast, accurate, good for most tasks
   └─ Size: ~4 GB
   └─ Speed: Fast inference
   └─ When to use: General purpose, default choice

2. neural-chat (7B, optimized for chat)
   └─ Size: ~4 GB
   └─ Speed: Fast
   └─ When to use: Better for conversations
```

**How to pull (via OpenWebUI)**:
1. Open https://ollama.mylegion5pro.me/
2. Settings → Models
3. Search for "mistral"
4. Click "Download"
5. Wait for download to complete

---

#### **Tier 2: Enhanced (13-15GB)**
```
1. llama2:13b
   └─ Size: ~7 GB
   └─ Speed: Medium
   └─ Capability: Better reasoning
   └─ When to use: Complex tasks, reasoning

2. mistral:large
   └─ Size: ~13 GB
   └─ Speed: Medium
   └─ Capability: Very capable
   └─ When to use: Advanced tasks
```

---

#### **Tier 3: Advanced (33-70GB)**
```
1. llama2:70b
   └─ Size: ~39 GB
   └─ Speed: Slower (CPU only)
   └─ Capability: Excellent reasoning
   └─ Warning: Requires significant resources
   └─ When to use: Only if talos-worker4 has GPU or huge RAM

2. mixtral:latest
   └─ Size: ~26 GB
   └─ Speed: Medium (better than llama2:70b)
   └─ Capability: Excellent
   └─ When to use: Best quality/speed tradeoff
```

---

### Phase 4: Configure Applications to Use Models

#### **For Flowise**
```
In Flowise UI:
1. Go to node selection
2. Select "LLM" node
3. Choose provider: "Ollama"
4. URL: http://ollama-service.default.svc.cluster.local:11434
5. Select model: mistral (or your chosen model)
6. Test connection ✅
```

#### **For n8n**
```
In n8n:
1. Create node: "HTTP Request"
2. Configure:
   └─ URL: http://ollama-service.default.svc.cluster.local:11434/api/generate
   └─ Method: POST
   └─ Body: {"model": "mistral", "prompt": "..."}
3. Test call
```

---

## Resource Requirements

### Ollama Memory Requirements

| Model | Size | RAM Needed | CPU | GPU |
|-------|------|-----------|-----|-----|
| **mistral:7b** | 4 GB | 8 GB | OK | Better |
| **llama2:13b** | 7 GB | 16 GB | OK | Better |
| **llama2:70b** | 39 GB | 80 GB | Slow | Needed |
| **mixtral:8x7b** | 26 GB | 48 GB | OK | Better |

### Current Resources

```
talos-worker4 (when activated):
├─ CPU: 4 cores
├─ RAM: 8 GB
├─ GPU: None
└─ Sufficient for: mistral:7b, neural-chat

Options if more capacity needed:
✅ Can increase talos-worker4 to 8-16 GB RAM
✅ Can add GPU support (future enhancement)
✅ Can scale to multiple inference nodes
```

---

## Quick Start: Mistral 7B Model

### Recommended for immediate deployment

```
Why Mistral 7B?
✅ Fits in 8 GB RAM with headroom
✅ Fast inference (good for interactive use)
✅ High quality responses
✅ Good for chat, Q&A, coding
✅ Works on CPU-only systems
```

### Deployment Steps

**Step 1: Activate talos-worker4**
```bash
ssh root@192.168.1.191
qm start 112
```

**Step 2: Wait for node to join cluster (2-3 min)**
```bash
kubectl get nodes
# Wait for talos-worker4 to show as Ready
```

**Step 3: Pull mistral model**
```bash
# Option A: Via OpenWebUI (easy)
# Go to https://ollama.mylegion5pro.me/ → Settings → Models → mistral

# Option B: Via command line
kubectl exec -it -n default deployment/ollama -- ollama pull mistral
```

**Step 4: Verify model is loaded**
```bash
# Visit https://ollama.mylegion5pro.me/
# You should see "mistral" in the models list
```

**Step 5: Test in Flowise**
```
1. Go to https://flowise.lupulup.com
2. Create chatflow
3. Add "LLM" node
4. Provider: Ollama
5. URL: http://ollama-service.default.svc.cluster.local:11434
6. Model: mistral
7. Test: Ask it a question
```

---

## Timeline & Effort

### Phase 1: Activate Worker4
- **Time**: 5 minutes
- **Effort**: Very low (1 SSH command)
- **Risk**: Very low

### Phase 2: Pull Model
- **Time**: 5-15 minutes (depends on internet speed)
- **Effort**: Very low (2-3 clicks in UI)
- **Risk**: Very low

### Phase 3: Configure Applications
- **Time**: 10-20 minutes
- **Effort**: Low (configuration in UI)
- **Risk**: Very low

**Total**: 20-50 minutes end-to-end
**Result**: ✅ Fully functional local LLM infrastructure

---

## Alternative: If You Don't Want to Activate talos-worker4

### Still Possible, But:
- ✅ Can use mistral:7b on current talos-worker1
- ✅ Would work for basic use
- ⚠️ Resource contention with other services
- ⚠️ Potential performance issues
- ⚠️ Can't run multiple models simultaneously
- ⚠️ Limited to smaller models

**Recommendation**: Still activate talos-worker4 for better performance

---

## Models Comparison Table

```
┌──────────────┬─────────┬──────────┬───────────┬────────┐
│ Model        │ Size    │ RAM      │ Speed     │ Quality│
├──────────────┼─────────┼──────────┼───────────┼────────┤
│ mistral:7b   │ 4 GB    │ 8 GB     │ ⚡⚡⚡     │ ⭐⭐⭐⭐ │
│ neural-chat  │ 4 GB    │ 8 GB     │ ⚡⚡⚡     │ ⭐⭐⭐⭐ │
│ llama2:13b   │ 7 GB    │ 16 GB    │ ⚡⚡      │ ⭐⭐⭐⭐⭐│
│ mixtral:8x7b │ 26 GB   │ 48 GB    │ ⚡⚡      │ ⭐⭐⭐⭐⭐│
│ llama2:70b   │ 39 GB   │ 80 GB    │ ⚡       │ ⭐⭐⭐⭐⭐│
└──────────────┴─────────┴──────────┴───────────┴────────┘

Legend: ⚡ = speed, ⭐ = quality
```

---

## Next Steps

### Immediate Actions (Do These Now)

1. **Decide on activation**:
   - [ ] Activate talos-worker4 now (recommended)
   - OR
   - [ ] Use existing talos-worker1 (simpler, but suboptimal)

2. **Choose model**:
   - [ ] Mistral 7B (recommended for balance)
   - [ ] Neural-Chat (better for conversations)
   - [ ] Other (specify)

3. **Plan deployment**:
   - [ ] Set deployment timeline
   - [ ] Assign person to execute

### Execution Steps

1. [ ] Activate talos-worker4
2. [ ] Pull chosen LLM model
3. [ ] Configure Flowise to use model
4. [ ] Configure n8n to use model
5. [ ] Test end-to-end workflow
6. [ ] Document setup

---

## Success Criteria

### After Deployment

You'll be able to:
- ✅ Ask questions via Flowise chatflows
- ✅ Use LLM in n8n workflows
- ✅ Get responses from local model (no external API)
- ✅ Build AI applications with custom logic
- ✅ Scale to multiple models if needed

### Verification

```
Test 1: Flowise LLM Node
├─ Create simple chatflow with LLM
├─ Ask "What is 2+2?"
└─ Expect: "4"

Test 2: n8n LLM Integration
├─ Create n8n workflow with Ollama call
├─ Send prompt: "Say hello"
└─ Expect: Response from model

Test 3: Multiple Models
├─ Pull second model (e.g., neural-chat)
├─ Switch between models
└─ Expect: Both work independently
```

---

## Troubleshooting

### If models don't load in Flowise
```
1. Check Ollama is running:
   kubectl get pods -n default -l app=ollama

2. Verify model exists:
   curl http://ollama-service.default:11434/api/tags

3. Check network connectivity:
   kubectl exec -it -n local-ai-flowise deployment/flowise -- \
     curl http://ollama-service.default:11434/api/tags

4. Check logs:
   kubectl logs -n default deployment/ollama
```

### If model is slow
```
Reasons:
├─ Model too large for available RAM
├─ CPU only (no GPU)
├─ Other workloads consuming resources
└─ Network latency

Solutions:
├─ Switch to smaller model (mistral:7b instead of 70b)
├─ Increase worker RAM (optional)
├─ Add GPU (future enhancement)
└─ Activate talos-worker4 for dedicated inference
```

---

## Summary

### What You Need to Do

```
✅ Required:
   1. Activate talos-worker4 (5 min)
   2. Pull LLM model (10 min)
   3. Configure Flowise/n8n (15 min)

✅ Result:
   Fully functional local LLM infrastructure
   All AI operations using local models
   Better performance and privacy

✅ Benefit:
   Independent from external APIs
   No subscription costs
   Full control over models
   Local data processing
```

---

**Status**: Ready to implement
**Effort**: Low
**Time**: <1 hour
**Impact**: Critical for AI operations

**Recommendation**: Activate talos-worker4 and deploy Mistral 7B model today.
