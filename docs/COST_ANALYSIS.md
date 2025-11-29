# AI Study Companion - Cost Analysis

## Executive Summary

This document provides comprehensive cost projections for the AI Study Companion, including AI API costs, infrastructure expenses, and scaling forecasts for the first 90 days.

---

## AI API Costs

### Model Pricing (as of November 2024)

| Model | Input (per 1K tokens) | Output (per 1K tokens) | Use Case |
|-------|----------------------|------------------------|----------|
| GPT-4 Turbo | $0.01 | $0.03 | Primary conversations |
| GPT-4o | $0.005 | $0.015 | Cost-optimized option |
| GPT-3.5 Turbo | $0.0005 | $0.0015 | Simple queries |

### Token Usage Estimates

Based on conversation analysis:

| Metric | Average | Notes |
|--------|---------|-------|
| Tokens per user message | 50-100 | Student questions |
| Tokens per AI response | 200-400 | Detailed explanations |
| System prompt tokens | 500 | Context + memory |
| Messages per session | 10-15 | Typical conversation |

### Per-Session Cost Calculation

**Standard Conversation (GPT-4 Turbo)**
```
Input tokens: (500 + 100) × 12 messages = 7,200 tokens
Output tokens: 300 × 12 messages = 3,600 tokens

Cost = (7,200 / 1000 × $0.01) + (3,600 / 1000 × $0.03)
     = $0.072 + $0.108
     = $0.18 per session
```

**With Caching (30% hit rate)**
```
Effective cost = $0.18 × 0.70 = $0.126 per session
```

**With GPT-4o (cost-optimized)**
```
Input: (7,200 / 1000 × $0.005) = $0.036
Output: (3,600 / 1000 × $0.015) = $0.054
Total = $0.09 per session
With caching = $0.063 per session
```

### Practice Question Generation

| Component | Tokens | Cost (GPT-3.5) |
|-----------|--------|----------------|
| Question generation (10 Qs) | 2,000 | $0.001 |
| Answer evaluation (10 Qs) | 3,000 | $0.0015 |
| **Total per practice session** | 5,000 | $0.0025 |

---

## Monthly Cost Projections by User Scale

### Assumptions
- Average 3 conversation sessions/student/week
- Average 2 practice sessions/student/week
- 4.3 weeks per month
- 30% cache hit rate
- Using GPT-4 Turbo for conversations, GPT-3.5 for practice

### Cost per Active Student per Month

```
Conversations: 3 × 4.3 × $0.126 = $1.63
Practice: 2 × 4.3 × $0.0025 = $0.02
Total AI cost per student: $1.65/month
```

### Scaling Projections

| Active Students | Monthly AI Cost | Infrastructure | Total Monthly |
|-----------------|-----------------|----------------|---------------|
| 100 | $165 | $200 | $365 |
| 500 | $825 | $350 | $1,175 |
| 1,000 | $1,650 | $500 | $2,150 |
| 5,000 | $8,250 | $1,500 | $9,750 |
| 10,000 | $16,500 | $3,000 | $19,500 |
| 50,000 | $82,500 | $12,000 | $94,500 |

---

## Infrastructure Costs (AWS)

### Base Infrastructure (100-1,000 users)

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| ECS Fargate (API) | 2 × 1 vCPU, 2GB | $75 |
| RDS PostgreSQL | db.t3.medium | $65 |
| ElastiCache Redis | cache.t3.medium | $45 |
| CloudFront | 100GB transfer | $15 |
| S3 | 10GB storage | $5 |
| Secrets Manager | 5 secrets | $5 |
| CloudWatch | Basic monitoring | $10 |
| **Total** | | **$220** |

### Growth Infrastructure (1,000-10,000 users)

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| ECS Fargate (API) | 4 × 2 vCPU, 4GB | $300 |
| RDS PostgreSQL | db.r5.large, Multi-AZ | $350 |
| ElastiCache Redis | cache.r5.large | $200 |
| CloudFront | 500GB transfer | $50 |
| S3 | 50GB storage | $10 |
| Application Load Balancer | | $25 |
| CloudWatch | Enhanced | $50 |
| WAF | Basic rules | $15 |
| **Total** | | **$1,000** |

### Enterprise Infrastructure (10,000+ users)

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| ECS Fargate (API) | 8 × 4 vCPU, 8GB | $1,200 |
| RDS PostgreSQL | db.r5.xlarge, Multi-AZ | $700 |
| ElastiCache Redis | cache.r5.xlarge, cluster | $500 |
| CloudFront | 2TB transfer | $150 |
| S3 | 200GB storage | $30 |
| Application Load Balancer | | $50 |
| CloudWatch | Full observability | $150 |
| WAF | Advanced rules | $50 |
| Backup & DR | Cross-region | $200 |
| **Total** | | **$3,030** |

---

## 90-Day Cost Forecast

### Phase 1: Beta (Days 1-30)
- Target users: 100
- Focus: Core functionality, bug fixes

| Category | Cost |
|----------|------|
| AI API | $165 |
| Infrastructure | $220 |
| **Monthly Total** | **$385** |

### Phase 2: Limited Launch (Days 31-60)
- Target users: 500
- Focus: Tutor integration, refinement

| Category | Cost |
|----------|------|
| AI API | $825 |
| Infrastructure | $350 |
| **Monthly Total** | **$1,175** |

### Phase 3: Expansion (Days 61-90)
- Target users: 2,000
- Focus: Scale testing, optimization

| Category | Cost |
|----------|------|
| AI API | $3,300 |
| Infrastructure | $750 |
| **Monthly Total** | **$4,050** |

### 90-Day Total: $5,610

---

## Cost Optimization Strategies

### 1. Intelligent Caching (Saves 20-40%)
```ruby
# Cache common explanations
cache_key = "explanation:#{topic}:#{difficulty}:#{grade_level}"
@redis.get(cache_key) || generate_and_cache(cache_key)
```
Expected savings: 30% on repeat queries

### 2. Model Tiering (Saves 30-50%)
```ruby
def select_model(query_type)
  case query_type
  when :simple_question then 'gpt-3.5-turbo'
  when :practice_eval then 'gpt-3.5-turbo'
  when :complex_explanation then 'gpt-4-turbo'
  when :essay_feedback then 'gpt-4-turbo'
  end
end
```
Route 60% of requests to GPT-3.5: 40% cost reduction on those requests

### 3. Prompt Optimization (Saves 10-20%)
- Compress system prompts
- Summarize conversation history
- Limit context window

Before: 500 token system prompt
After: 300 token optimized prompt
Savings: 40% on input tokens

### 4. Batch Processing (Saves 5-15%)
- Generate practice questions in batches
- Pre-generate common content during off-peak
- Use batch API for non-real-time tasks

### 5. Regional Optimization
- Deploy to closest AWS region
- Use CloudFront for API caching where appropriate
- Consider reserved instances for predictable workloads

---

## Break-Even Analysis

### Assumptions
- Average tutoring subscription: $200/month
- AI Companion as add-on: $15/month premium
- Alternatively: Reduces churn by X%

### Scenario 1: Premium Add-On
```
Revenue per user: $15/month
Cost per user: $1.65 (AI) + $0.50 (infra) = $2.15/month
Margin: $12.85/user/month (85.7% margin)

Break-even: ~10 users covers base infrastructure
```

### Scenario 2: Churn Reduction
```
If companion reduces churn by 10%:
- Current monthly churn: 5%
- With companion: 4.5%

For 1,000 users at $200/month:
Retained revenue = 5 users × $200 = $1,000/month
Companion cost = 1,000 × $2.15 = $2,150/month

Break-even churn reduction: 1.1% (22 users/2,000)
```

### Scenario 3: Session Utilization
```
If companion increases session completion by 15%:
- Less rescheduling = reduced operations cost
- Higher tutor utilization = better margins

Estimated value: $3-5/student/month in efficiency gains
```

---

## Risk Factors & Mitigations

### 1. AI Price Changes
- **Risk**: OpenAI price increases
- **Mitigation**: Multi-provider support (Claude, Gemini ready)

### 2. Usage Spikes
- **Risk**: Viral adoption exceeds projections
- **Mitigation**: Auto-scaling, rate limiting, usage caps

### 3. Model Degradation
- **Risk**: AI quality issues affect UX
- **Mitigation**: Model versioning, fallback chains, monitoring

### 4. Competitive Pressure
- **Risk**: Commoditization of AI tutoring
- **Mitigation**: Deep Nerdy platform integration, tutor handoff

---

## Recommendations

1. **Start with GPT-4 Turbo** for quality, plan migration to GPT-4o
2. **Implement caching early** - low effort, high impact
3. **Monitor cost per conversation** as key metric
4. **Set up usage alerts** at 80% of budget thresholds
5. **Plan for multi-model** architecture from day one

---

## Appendix: Token Counting Reference

```ruby
# Token estimation (rough)
def estimate_tokens(text)
  # Average: 1 token ≈ 4 characters for English
  (text.length / 4.0).ceil
end

# Accurate counting with tiktoken
require 'tiktoken_ruby'
encoder = Tiktoken.encoding_for_model('gpt-4')
token_count = encoder.encode(text).length
```

---

*Last updated: November 2024*
*Version: 1.0*


