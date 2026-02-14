# factory_observability

**Purpose**: Instrument factory runs and products with OpenTelemetry (OTel) for visibility, debugging, and continuous improvement.

**When to use**: When implementing products or when analyzing factory performance. Provides structured telemetry (traces, metrics, logs) for the entire factory operation.

## Overview

The SF factory is a **meta-system**: it builds products using LLMs. Observability is critical at two levels:

1. **Factory-level**: Pipeline execution, stage transitions, LLM calls, adjudication decisions
2. **Product-level**: The products themselves emit telemetry (if instrumented)

This skill covers both levels.

## Why Observability Matters

### Factory-Level
- Which stages take longest? (optimize prompts or retry logic)
- Which LLM produces better code? (track adjudication outcomes)
- Where do pipelines fail most? (improve error handling)
- What's the cost per run? (track tokens, API calls)

### Product-Level
- Does the product work correctly in production?
- Where are performance bottlenecks?
- Are errors happening in user flows?
- How is the product being used?

## OpenTelemetry Primer

OTel provides three telemetry types:

1. **Traces**: Distributed request flow (spans form a tree)
   - Example: `run_pipeline` → `plan_stage` → `llm_call` → `adjudicate`

2. **Metrics**: Numerical measurements over time
   - Example: `pipeline.stage.duration`, `llm.tokens.total`, `test.pass_rate`

3. **Logs**: Structured event records
   - Example: `{"level":"info", "stage":"typecheck", "outcome":"success"}`

All three are correlated by **trace context** (trace_id, span_id).

## Factory-Level Instrumentation

### Pipeline Execution Tracing

Each pipeline run creates a root span:

```typescript
// scripts/run-pipeline.ts
import { trace, context } from '@opentelemetry/api'

const tracer = trace.getTracer('sf-factory')

async function runPipeline(pipelineName: string, runId: string) {
  const span = tracer.startSpan('pipeline.run', {
    attributes: {
      'pipeline.name': pipelineName,
      'run.id': runId,
      'run.timestamp': new Date().toISOString(),
    }
  })

  const ctx = trace.setSpan(context.active(), span)

  try {
    await context.with(ctx, async () => {
      // Execute pipeline stages
      await runStages(pipelineName, runId)
    })

    span.setStatus({ code: SpanStatusCode.OK })
  } catch (error) {
    span.recordException(error as Error)
    span.setStatus({ code: SpanStatusCode.ERROR, message: error.message })
    throw error
  } finally {
    span.end()
  }
}
```

### Stage-Level Spans

Each stage in the pipeline is a child span:

```typescript
async function executeStage(stageName: string, prompt: string) {
  const span = tracer.startSpan('pipeline.stage', {
    attributes: {
      'stage.name': stageName,
      'stage.prompt_length': prompt.length,
    }
  })

  try {
    const result = await callLLM(prompt)

    span.setAttribute('stage.outcome', result.outcome)
    span.setAttribute('stage.duration_ms', result.duration)
    span.setStatus({ code: SpanStatusCode.OK })

    return result
  } catch (error) {
    span.recordException(error as Error)
    span.setStatus({ code: SpanStatusCode.ERROR })
    throw error
  } finally {
    span.end()
  }
}
```

### LLM Call Tracing

Track every LLM interaction:

```typescript
async function callLLM(prompt: string, model: string, provider: string) {
  const span = tracer.startSpan('llm.call', {
    attributes: {
      'llm.provider': provider,
      'llm.model': model,
      'llm.prompt_tokens': estimateTokens(prompt),
    }
  })

  const startTime = Date.now()

  try {
    const response = await llmClient.chat(prompt, model)

    const duration = Date.now() - startTime

    span.setAttributes({
      'llm.completion_tokens': response.usage.completion_tokens,
      'llm.total_tokens': response.usage.total_tokens,
      'llm.duration_ms': duration,
      'llm.finish_reason': response.finish_reason,
    })

    span.setStatus({ code: SpanStatusCode.OK })
    return response
  } catch (error) {
    span.recordException(error as Error)
    span.setStatus({ code: SpanStatusCode.ERROR })
    throw error
  } finally {
    span.end()
  }
}
```

### Tournament Adjudication Tracing

Track parallel implementations and selection:

```typescript
async function adjudicate(codexImpl: Artifact, claudeImpl: Artifact) {
  const span = tracer.startSpan('pipeline.adjudicate', {
    attributes: {
      'adjudication.candidates': 2,
    }
  })

  try {
    // Evaluate both
    const codexScore = await evaluateImplementation(codexImpl)
    const claudeScore = await evaluateImplementation(claudeImpl)

    span.setAttributes({
      'adjudication.codex_score': codexScore.total,
      'adjudication.claude_score': claudeScore.total,
      'adjudication.codex_tests_passed': codexScore.testsPassed,
      'adjudication.claude_tests_passed': claudeScore.testsPassed,
    })

    const selected = codexScore.total >= claudeScore.total ? 'codex' : 'claude'

    span.setAttribute('adjudication.selected', selected)
    span.setStatus({ code: SpanStatusCode.OK })

    return selected === 'codex' ? codexImpl : claudeImpl
  } finally {
    span.end()
  }
}
```

### Metrics Collection

Track factory performance metrics:

```typescript
import { metrics } from '@opentelemetry/api'

const meter = metrics.getMeter('sf-factory')

// Counters
const pipelineRunsCounter = meter.createCounter('pipeline.runs.total', {
  description: 'Total pipeline runs',
})

const stageRetriesCounter = meter.createCounter('pipeline.stage.retries.total', {
  description: 'Stage retry attempts',
})

// Histograms
const stageDurationHistogram = meter.createHistogram('pipeline.stage.duration', {
  description: 'Stage execution duration in seconds',
  unit: 's',
})

const llmTokensHistogram = meter.createHistogram('llm.tokens.total', {
  description: 'LLM token usage per call',
})

// Usage
pipelineRunsCounter.add(1, { 'pipeline.name': 'new_product', 'outcome': 'success' })
stageDurationHistogram.record(42.5, { 'stage.name': 'typecheck', 'outcome': 'success' })
llmTokensHistogram.record(1523, { 'llm.provider': 'openai', 'llm.model': 'gpt-5.3-codex' })
```

## Product-Level Instrumentation

Products built by the factory should also emit telemetry.

### Next.js + Vercel Instrumentation

Add to template (`templates/ts-next-convex-vercel/lib/observability.ts`):

```typescript
import { trace, context } from '@opentelemetry/api'
import { WebTracerProvider } from '@opentelemetry/sdk-trace-web'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http'
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { Resource } from '@opentelemetry/resources'
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions'

let initialized = false

export function initObservability() {
  if (initialized) return
  if (!process.env.NEXT_PUBLIC_OTEL_ENDPOINT) {
    console.warn('OTEL endpoint not configured, skipping instrumentation')
    return
  }

  const provider = new WebTracerProvider({
    resource: new Resource({
      [SemanticResourceAttributes.SERVICE_NAME]: 'product-webapp',
      [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    }),
  })

  const exporter = new OTLPTraceExporter({
    url: process.env.NEXT_PUBLIC_OTEL_ENDPOINT,
  })

  provider.addSpanProcessor(new BatchSpanProcessor(exporter))
  provider.register()

  initialized = true
}

// Call in app/layout.tsx
```

### Instrument User Interactions

```typescript
// components/CreateTaskButton.tsx
import { trace } from '@opentelemetry/api'

const tracer = trace.getTracer('product-webapp')

export function CreateTaskButton() {
  const handleClick = async () => {
    const span = tracer.startSpan('user.create_task')

    try {
      const task = await createTask({ title: 'New task' })
      span.setAttribute('task.id', task.id)
      span.setStatus({ code: SpanStatusCode.OK })
    } catch (error) {
      span.recordException(error as Error)
      span.setStatus({ code: SpanStatusCode.ERROR })
    } finally {
      span.end()
    }
  }

  return <button onClick={handleClick}>Create Task</button>
}
```

### Backend API Tracing (FastAPI)

For Python backends (`templates/ts-next-fastapi-fly/backend/src/infrastructure/observability.py`):

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.semconv.resource import ResourceAttributes
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
import os

def init_observability(app):
    """Initialize OpenTelemetry for FastAPI app."""
    endpoint = os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT')
    if not endpoint:
        print("OTEL endpoint not configured, skipping instrumentation")
        return

    resource = Resource(attributes={
        ResourceAttributes.SERVICE_NAME: "product-api",
        ResourceAttributes.SERVICE_VERSION: "1.0.0",
    })

    provider = TracerProvider(resource=resource)
    exporter = OTLPSpanExporter(endpoint=endpoint)
    processor = BatchSpanProcessor(exporter)
    provider.add_span_processor(processor)
    trace.set_tracer_provider(provider)

    # Auto-instrument FastAPI
    FastAPIInstrumentor.instrument_app(app)

# In src/main.py
from infrastructure.observability import init_observability

app = FastAPI()
init_observability(app)
```

## OTel Collector Setup

Deploy an OTel collector to receive telemetry:

```yaml
# docker-compose.yml (for local development)
version: '3.8'

services:
  otel-collector:
    image: otel/opentelemetry-collector:latest
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
    ports:
      - "4318:4318"  # OTLP HTTP receiver
      - "13133:13133"  # Health check

  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"  # Jaeger UI
      - "14250:14250"  # Jaeger gRPC
```

OTel collector config:

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s

exporters:
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true

  logging:
    loglevel: debug

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [jaeger, logging]
```

Start:
```bash
docker-compose up -d
```

Access Jaeger UI: http://localhost:16686

## Environment Configuration

### Factory
```bash
# .env
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318/v1/traces
OTEL_SERVICE_NAME=sf-factory
```

### Products
```bash
# Product .env.local
NEXT_PUBLIC_OTEL_ENDPOINT=http://localhost:4318/v1/traces
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318/v1/traces  # For server-side
```

## Querying Telemetry

### Jaeger UI
1. Open http://localhost:16686
2. Select service: `sf-factory` or `product-webapp`
3. Search traces by:
   - Time range
   - Tags (e.g., `pipeline.name=new_product`)
   - Duration (e.g., `> 30s`)

### Trace Analysis
Find slow stages:
- Look for spans with high duration
- Identify bottlenecks (LLM calls, test execution)
- Optimize prompts or retry logic

Find failure patterns:
- Filter by `status.code=ERROR`
- Group by `stage.name` to find flaky stages
- Examine exception details in span events

## Cost Tracking

Track LLM token usage and estimate costs:

```typescript
// Track tokens per run
const tokenMetrics = {
  openai: {
    'gpt-5.3-codex': { input: 0, output: 0 },
    'gpt-5.3-codex-spark': { input: 0, output: 0 },
  },
  anthropic: {
    'opus': { input: 0, output: 0 },
    'sonnet': { input: 0, output: 0 },
  },
}

// After each LLM call
function recordTokenUsage(provider: string, model: string, usage: TokenUsage) {
  tokenMetrics[provider][model].input += usage.prompt_tokens
  tokenMetrics[provider][model].output += usage.completion_tokens

  // Emit metric
  llmTokensHistogram.record(usage.total_tokens, {
    'llm.provider': provider,
    'llm.model': model,
    'llm.token_type': 'total',
  })
}

// Calculate cost at end of run
function estimateCost(tokenMetrics: TokenMetrics): number {
  const pricing = {
    'gpt-5.3-codex': { input: 0.03, output: 0.06 },  // per 1K tokens
    'opus': { input: 0.015, output: 0.075 },
  }

  let totalCost = 0
  for (const [provider, models] of Object.entries(tokenMetrics)) {
    for (const [model, usage] of Object.entries(models)) {
      const price = pricing[model]
      totalCost += (usage.input / 1000) * price.input
      totalCost += (usage.output / 1000) * price.output
    }
  }

  return totalCost
}
```

## Dashboard Visualization

Use Grafana to visualize metrics:

```yaml
# docker-compose.yml
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

Prometheus config:
```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:8888']
```

Grafana dashboards:
- **Pipeline Overview**: Runs per day, success rate, avg duration
- **Stage Performance**: Duration per stage, retry counts
- **LLM Usage**: Tokens per provider/model, cost per run
- **Test Quality**: Pass rate, flaky test detection

## Alerting

Set up alerts for factory issues:

```yaml
# alertmanager.yml
groups:
  - name: factory_alerts
    interval: 1m
    rules:
      - alert: HighPipelineFailureRate
        expr: rate(pipeline_runs_total{outcome="fail"}[5m]) > 0.5
        for: 5m
        annotations:
          summary: "High pipeline failure rate"
          description: "More than 50% of pipelines failing in last 5min"

      - alert: StageDurationAnomaly
        expr: pipeline_stage_duration > 300
        for: 1m
        annotations:
          summary: "Stage taking too long"
          description: "Stage {{ $labels.stage_name }} took {{ $value }}s"
```

## Best Practices

1. **Always instrument new stages**
   - Add span creation to every pipeline stage
   - Track outcomes and durations

2. **Use semantic attributes**
   - Follow OTel semantic conventions
   - Consistent naming (e.g., `pipeline.name`, `stage.outcome`)

3. **Correlate factory and product traces**
   - Propagate trace context from factory to product
   - See full flow: pipeline → deploy → user interaction

4. **Sample strategically**
   - 100% sampling for factory (low volume)
   - Tail sampling for products (catch errors + random sample)

5. **Secure endpoints**
   - Don't expose OTel endpoints publicly
   - Use auth tokens in production

6. **Monitor collector health**
   - Ensure collector is running
   - Alert if collector down (telemetry loss)

## Summary

Factory observability provides:

- ✅ **Visibility** into pipeline execution
- ✅ **Debugging** for failed runs
- ✅ **Optimization** insights (slow stages, expensive LLM calls)
- ✅ **Cost tracking** for LLM usage
- ✅ **Quality metrics** (pass rates, retry counts)

Instrument early, observe continuously, improve systematically.
