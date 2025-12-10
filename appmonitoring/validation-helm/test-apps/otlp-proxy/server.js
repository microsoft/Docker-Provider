// OTLP Proxy Server - Intercepts, logs, and forwards OTLP metrics
const express = require('express');
const axios = require('axios');
const protobuf = require('protobufjs');
const zlib = require('zlib');

const app = express();
const PORT = process.env.PORT || 4318;
const FORWARD_ENDPOINT = process.env.FORWARD_ENDPOINT || 'http://localhost:56682';

// Load OpenTelemetry protobuf definitions
let MetricsData;

async function loadProtoDefinitions() {
  try {
    console.log('[OTLP-PROXY] Loading OpenTelemetry protobuf definitions...');
    
    // Use protobuf.parse to load from string - works with official .proto syntax
    // This schema matches OpenTelemetry proto v1.0.0 with all known fields
    const protoSource = `
syntax = "proto3";

package opentelemetry.proto.metrics.v1;

import "opentelemetry/proto/common/v1/common.proto";
import "opentelemetry/proto/resource/v1/resource.proto";

message MetricsData {
  repeated ResourceMetrics resource_metrics = 1;
}

message ResourceMetrics {
  opentelemetry.proto.resource.v1.Resource resource = 1;
  repeated ScopeMetrics scope_metrics = 2;
  string schema_url = 3;
}

message ScopeMetrics {
  opentelemetry.proto.common.v1.InstrumentationScope scope = 1;
  repeated Metric metrics = 2;
  string schema_url = 3;
}

message Metric {
  string name = 1;
  string description = 2;
  string unit = 3;
  oneof data {
    Gauge gauge = 5;
    Sum sum = 7;
    Histogram histogram = 9;
    ExponentialHistogram exponential_histogram = 10;
    Summary summary = 11;
  }
}

message Gauge {
  repeated NumberDataPoint data_points = 1;
}

message Sum {
  repeated NumberDataPoint data_points = 1;
  AggregationTemporality aggregation_temporality = 2;
  bool is_monotonic = 3;
}

message Histogram {
  repeated HistogramDataPoint data_points = 1;
  AggregationTemporality aggregation_temporality = 2;
}

message ExponentialHistogram {
  repeated ExponentialHistogramDataPoint data_points = 1;
  AggregationTemporality aggregation_temporality = 2;
}

message Summary {
  repeated SummaryDataPoint data_points = 1;
}

message NumberDataPoint {
  repeated opentelemetry.proto.common.v1.KeyValue attributes = 7;
  fixed64 start_time_unix_nano = 2;
  fixed64 time_unix_nano = 3;
  oneof value {
    double as_double = 4;
    sfixed64 as_int = 6;
  }
  repeated Exemplar exemplars = 5;
  uint32 flags = 8;
}

message HistogramDataPoint {
  repeated opentelemetry.proto.common.v1.KeyValue attributes = 9;
  fixed64 start_time_unix_nano = 2;
  fixed64 time_unix_nano = 3;
  fixed64 count = 4;
  optional double sum = 5;
  repeated fixed64 bucket_counts = 6;
  repeated double explicit_bounds = 7;
  repeated Exemplar exemplars = 8;
  uint32 flags = 12;
  optional double min = 10;
  optional double max = 11;
}

message ExponentialHistogramDataPoint {
  repeated opentelemetry.proto.common.v1.KeyValue attributes = 1;
  fixed64 start_time_unix_nano = 2;
  fixed64 time_unix_nano = 3;
  fixed64 count = 4;
  optional double sum = 5;
  sint32 scale = 6;
  fixed64 zero_count = 7;
  Buckets positive = 8;
  Buckets negative = 9;
  uint32 flags = 12;
  repeated Exemplar exemplars = 13;
  optional double min = 10;
  optional double max = 11;
  double zero_threshold = 14;
}

message Buckets {
  sint32 offset = 1;
  repeated uint64 bucket_counts = 2;
}

message SummaryDataPoint {
  repeated opentelemetry.proto.common.v1.KeyValue attributes = 7;
  fixed64 start_time_unix_nano = 2;
  fixed64 time_unix_nano = 3;
  fixed64 count = 4;
  double sum = 5;
  repeated ValueAtQuantile quantile_values = 6;
  uint32 flags = 8;
}

message ValueAtQuantile {
  double quantile = 1;
  double value = 2;
}

message Exemplar {
  repeated opentelemetry.proto.common.v1.KeyValue filtered_attributes = 7;
  fixed64 time_unix_nano = 2;
  oneof value {
    double as_double = 3;
    sfixed64 as_int = 6;
  }
  bytes span_id = 4;
  bytes trace_id = 5;
}

enum AggregationTemporality {
  AGGREGATION_TEMPORALITY_UNSPECIFIED = 0;
  AGGREGATION_TEMPORALITY_DELTA = 1;
  AGGREGATION_TEMPORALITY_CUMULATIVE = 2;
}
`;

    // For now, use the inline JSON schema since protobuf.parse requires all imports
    // This is the full OTLP v1.0.0 schema
    const root = protobuf.Root.fromJSON({
      nested: {
        opentelemetry: {
          nested: {
            proto: {
              nested: {
                common: {
                  nested: {
                    v1: {
                      nested: {
                        AnyValue: {
                          oneofs: { value: { oneof: ['stringValue', 'boolValue', 'intValue', 'doubleValue', 'arrayValue', 'kvlistValue', 'bytesValue'] } },
                          fields: {
                            stringValue: { type: 'string', id: 1 },
                            boolValue: { type: 'bool', id: 2 },
                            intValue: { type: 'int64', id: 3 },
                            doubleValue: { type: 'double', id: 4 },
                            arrayValue: { type: 'ArrayValue', id: 5 },
                            kvlistValue: { type: 'KeyValueList', id: 6 },
                            bytesValue: { type: 'bytes', id: 7 }
                          }
                        },
                        ArrayValue: { fields: { values: { rule: 'repeated', type: 'AnyValue', id: 1 } } },
                        KeyValueList: { fields: { values: { rule: 'repeated', type: 'KeyValue', id: 1 } } },
                        KeyValue: { fields: { key: { type: 'string', id: 1 }, value: { type: 'AnyValue', id: 2 } } },
                        InstrumentationScope: {
                          fields: {
                            name: { type: 'string', id: 1 },
                            version: { type: 'string', id: 2 },
                            attributes: { rule: 'repeated', type: 'KeyValue', id: 3 },
                            droppedAttributesCount: { type: 'uint32', id: 4 }
                          }
                        }
                      }
                    }
                  }
                },
                resource: {
                  nested: {
                    v1: {
                      nested: {
                        Resource: {
                          fields: {
                            attributes: { rule: 'repeated', type: 'opentelemetry.proto.common.v1.KeyValue', id: 1 },
                            droppedAttributesCount: { type: 'uint32', id: 2 }
                          }
                        }
                      }
                    }
                  }
                },
                metrics: {
                  nested: {
                    v1: {
                      nested: {
                        MetricsData: { fields: { resourceMetrics: { rule: 'repeated', type: 'ResourceMetrics', id: 1 } } },
                        ResourceMetrics: {
                          fields: {
                            resource: { type: 'opentelemetry.proto.resource.v1.Resource', id: 1 },
                            scopeMetrics: { rule: 'repeated', type: 'ScopeMetrics', id: 2 },
                            schemaUrl: { type: 'string', id: 3 }
                          }
                        },
                        ScopeMetrics: {
                          fields: {
                            scope: { type: 'opentelemetry.proto.common.v1.InstrumentationScope', id: 1 },
                            metrics: { rule: 'repeated', type: 'Metric', id: 2 },
                            schemaUrl: { type: 'string', id: 3 }
                          }
                        },
                        Metric: {
                          oneofs: { data: { oneof: ['gauge', 'sum', 'histogram', 'exponentialHistogram', 'summary'] } },
                          fields: {
                            name: { type: 'string', id: 1 },
                            description: { type: 'string', id: 2 },
                            unit: { type: 'string', id: 3 },
                            gauge: { type: 'Gauge', id: 5 },
                            sum: { type: 'Sum', id: 7 },
                            histogram: { type: 'Histogram', id: 9 },
                            exponentialHistogram: { type: 'ExponentialHistogram', id: 10 },
                            summary: { type: 'Summary', id: 11 }
                          }
                        },
                        Gauge: { fields: { dataPoints: { rule: 'repeated', type: 'NumberDataPoint', id: 1 } } },
                        Sum: {
                          fields: {
                            dataPoints: { rule: 'repeated', type: 'NumberDataPoint', id: 1 },
                            aggregationTemporality: { type: 'AggregationTemporality', id: 2 },
                            isMonotonic: { type: 'bool', id: 3 }
                          }
                        },
                        Histogram: {
                          fields: {
                            dataPoints: { rule: 'repeated', type: 'HistogramDataPoint', id: 1 },
                            aggregationTemporality: { type: 'AggregationTemporality', id: 2 }
                          }
                        },
                        ExponentialHistogram: {
                          fields: {
                            dataPoints: { rule: 'repeated', type: 'ExponentialHistogramDataPoint', id: 1 },
                            aggregationTemporality: { type: 'AggregationTemporality', id: 2 }
                          }
                        },
                        Summary: { fields: { dataPoints: { rule: 'repeated', type: 'SummaryDataPoint', id: 1 } } },
                        NumberDataPoint: {
                          oneofs: { value: { oneof: ['asDouble', 'asInt'] } },
                          fields: {
                            attributes: { rule: 'repeated', type: 'opentelemetry.proto.common.v1.KeyValue', id: 7 },
                            startTimeUnixNano: { type: 'fixed64', id: 2 },
                            timeUnixNano: { type: 'fixed64', id: 3 },
                            asDouble: { type: 'double', id: 4 },
                            asInt: { type: 'sfixed64', id: 6 },
                            exemplars: { rule: 'repeated', type: 'Exemplar', id: 5 },
                            flags: { type: 'uint32', id: 8 }
                          }
                        },
                        HistogramDataPoint: {
                          fields: {
                            attributes: { rule: 'repeated', type: 'opentelemetry.proto.common.v1.KeyValue', id: 9 },
                            startTimeUnixNano: { type: 'fixed64', id: 2 },
                            timeUnixNano: { type: 'fixed64', id: 3 },
                            count: { type: 'fixed64', id: 4 },
                            sum: { type: 'double', id: 5 },
                            bucketCounts: { rule: 'repeated', type: 'fixed64', id: 6 },
                            explicitBounds: { rule: 'repeated', type: 'double', id: 7 },
                            exemplars: { rule: 'repeated', type: 'Exemplar', id: 8 },
                            flags: { type: 'uint32', id: 12 },
                            min: { type: 'double', id: 10 },
                            max: { type: 'double', id: 11 }
                          }
                        },
                        ExponentialHistogramDataPoint: {
                          fields: {
                            attributes: { rule: 'repeated', type: 'opentelemetry.proto.common.v1.KeyValue', id: 1 },
                            startTimeUnixNano: { type: 'fixed64', id: 2 },
                            timeUnixNano: { type: 'fixed64', id: 3 },
                            count: { type: 'fixed64', id: 4 },
                            sum: { type: 'double', id: 5 },
                            scale: { type: 'sint32', id: 6 },
                            zeroCount: { type: 'fixed64', id: 7 },
                            positive: { type: 'Buckets', id: 8 },
                            negative: { type: 'Buckets', id: 9 },
                            flags: { type: 'uint32', id: 12 },
                            exemplars: { rule: 'repeated', type: 'Exemplar', id: 13 },
                            min: { type: 'double', id: 10 },
                            max: { type: 'double', id: 11 },
                            zeroThreshold: { type: 'double', id: 14 }
                          }
                        },
                        Buckets: {
                          fields: {
                            offset: { type: 'sint32', id: 1 },
                            bucketCounts: { rule: 'repeated', type: 'uint64', id: 2 }
                          }
                        },
                        SummaryDataPoint: {
                          fields: {
                            attributes: { rule: 'repeated', type: 'opentelemetry.proto.common.v1.KeyValue', id: 7 },
                            startTimeUnixNano: { type: 'fixed64', id: 2 },
                            timeUnixNano: { type: 'fixed64', id: 3 },
                            count: { type: 'fixed64', id: 4 },
                            sum: { type: 'double', id: 5 },
                            quantileValues: { rule: 'repeated', type: 'ValueAtQuantile', id: 6 },
                            flags: { type: 'uint32', id: 8 }
                          }
                        },
                        Exemplar: {
                          oneofs: { value: { oneof: ['asDouble', 'asInt'] } },
                          fields: {
                            filteredAttributes: { rule: 'repeated', type: 'opentelemetry.proto.common.v1.KeyValue', id: 7 },
                            timeUnixNano: { type: 'fixed64', id: 2 },
                            asDouble: { type: 'double', id: 3 },
                            asInt: { type: 'sfixed64', id: 6 },
                            spanId: { type: 'bytes', id: 4 },
                            traceId: { type: 'bytes', id: 5 }
                          }
                        },
                        ValueAtQuantile: {
                          fields: {
                            quantile: { type: 'double', id: 1 },
                            value: { type: 'double', id: 2 }
                          }
                        },
                        AggregationTemporality: {
                          values: {
                            AGGREGATION_TEMPORALITY_UNSPECIFIED: 0,
                            AGGREGATION_TEMPORALITY_DELTA: 1,
                            AGGREGATION_TEMPORALITY_CUMULATIVE: 2
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    });
    
    MetricsData = root.lookupType('opentelemetry.proto.metrics.v1.MetricsData');
    console.log('[OTLP-PROXY] ✅ Protobuf definitions loaded successfully');
  } catch (error) {
    console.error('[OTLP-PROXY] ❌ Failed to load protobuf definitions:', error.message);
  }
}

// Initialize protobuf definitions
loadProtoDefinitions();

// Middleware to parse raw body
app.use(express.raw({ type: '*/*', limit: '10mb' }));

// Log incoming requests
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Helper to extract value from data points
function extractValue(dataPoints) {
  if (!dataPoints || dataPoints.length === 0) return null;
  const dp = dataPoints[0]; // Take first data point
  return dp.asDouble !== undefined ? dp.asDouble : 
         dp.asInt !== undefined ? dp.asInt : 
         dp.value?.asDouble !== undefined ? dp.value.asDouble :
         dp.value?.asInt !== undefined ? dp.value.asInt :
         null;
}

// Helper to parse and log protobuf metrics
function logProtobufMetrics(buffer) {
  console.log('\n========== [OTLP-PROXY] Cow Metrics (Protobuf) ==========');
  console.log(`Buffer size: ${buffer.length} bytes`);
  
  if (!MetricsData) {
    console.log('⚠️ Protobuf definitions not loaded - cannot parse');
    console.log('Showing first 100 bytes (hex):', buffer.toString('hex').substring(0, 200));
    return;
  }
  
  try {
    // Try standard decode first
    const message = MetricsData.decode(buffer);
    const jsonData = MetricsData.toObject(message, {
      longs: String,
      enums: String,
      bytes: String,
      defaults: false
    });
    
    console.log('✅ Successfully decoded protobuf\n');
    
    // Now log cow metrics using same logic as JSON
    let foundAny = false;
    
    if (jsonData.resourceMetrics) {
      for (const resourceMetric of jsonData.resourceMetrics) {
        if (resourceMetric.scopeMetrics) {
          for (const scopeMetric of resourceMetric.scopeMetrics) {
            if (scopeMetric.metrics) {
              for (const metric of scopeMetric.metrics) {
                if (metric.name?.toLowerCase().includes('cow')) {
                  foundAny = true;
                  
                  // Determine metric type and extract details
                  let metricType = 'unknown';
                  let temporality = null;
                  let histogramType = null;
                  let value = null;
                  
                  if (metric.gauge) {
                    metricType = 'gauge';
                    value = extractValue(metric.gauge.dataPoints);
                  } else if (metric.sum) {
                    metricType = 'sum';
                    temporality = metric.sum.aggregationTemporality === '1' || metric.sum.aggregationTemporality === 1 ? 'DELTA' : 
                                 metric.sum.aggregationTemporality === '2' || metric.sum.aggregationTemporality === 2 ? 'CUMULATIVE' : 'UNSPECIFIED';
                    value = extractValue(metric.sum.dataPoints);
                  } else if (metric.histogram) {
                    metricType = 'histogram';
                    histogramType = 'explicit';
                    temporality = metric.histogram.aggregationTemporality === '1' || metric.histogram.aggregationTemporality === 1 ? 'DELTA' : 
                                 metric.histogram.aggregationTemporality === '2' || metric.histogram.aggregationTemporality === 2 ? 'CUMULATIVE' : 'UNSPECIFIED';
                    if (metric.histogram.dataPoints?.[0]) {
                      value = `count=${metric.histogram.dataPoints[0].count}, sum=${metric.histogram.dataPoints[0].sum}`;
                    }
                  } else if (metric.exponentialHistogram) {
                    metricType = 'histogram';
                    histogramType = 'exponential';
                    temporality = metric.exponentialHistogram.aggregationTemporality === '1' || metric.exponentialHistogram.aggregationTemporality === 1 ? 'DELTA' : 
                                 metric.exponentialHistogram.aggregationTemporality === '2' || metric.exponentialHistogram.aggregationTemporality === 2 ? 'CUMULATIVE' : 'UNSPECIFIED';
                    if (metric.exponentialHistogram.dataPoints?.[0]) {
                      value = `count=${metric.exponentialHistogram.dataPoints[0].count}, sum=${metric.exponentialHistogram.dataPoints[0].sum}`;
                    }
                  } else if (metric.summary) {
                    metricType = 'summary';
                    if (metric.summary.dataPoints?.[0]) {
                      value = `count=${metric.summary.dataPoints[0].count}, sum=${metric.summary.dataPoints[0].sum}`;
                    }
                  }
                  
                  // Print in clean format
                  console.log(`\n📊 ${metric.name}`);
                  console.log(`   Type: ${metricType}${histogramType ? ` (${histogramType})` : ''}`);
                  if (temporality) console.log(`   Temporality: ${temporality}`);
                  console.log(`   Value: ${value}`);
                }
              }
            }
          }
        }
      }
    }
    
    if (!foundAny) {
      console.log('\nNo cow metrics found in this batch');
    }
    
  } catch (decodeError) {
    console.error('\n❌ Protobuf decode error:', decodeError.message);
    
    // Show detailed error info
    if (decodeError.message.includes('wire type')) {
      const match = decodeError.message.match(/wire type (\d+) at offset (\d+)/);
      if (match) {
        const wireType = match[1];
        const offset = parseInt(match[2]);
        console.log(`\n⚠️ Invalid wire type ${wireType} at offset ${offset}`);
        
        // Analyze the problematic byte
        const byte = buffer[offset];
        const fieldNumber = byte >> 3;
        const wireTypeFromByte = byte & 0x07;
        console.log(`\nByte analysis at offset ${offset}:`);
        console.log(`  Byte value: 0x${byte.toString(16).padStart(2, '0')} (${byte})`);
        console.log(`  Field number: ${fieldNumber}`);
        console.log(`  Wire type: ${wireTypeFromByte}`);
        console.log(`  Valid wire types: 0=varint, 1=64bit, 2=length-delimited, 5=32bit`);
        
        // Show context
        console.log('\nContext (100 bytes around error):');
        const start = Math.max(0, offset - 50);
        const end = Math.min(buffer.length, offset + 50);
        const contextBuffer = buffer.subarray(start, end);
        
        // Format as hex with offset markers
        let hexStr = '';
        for (let i = 0; i < contextBuffer.length; i++) {
          if (i === offset - start) hexStr += '>>>';
          hexStr += contextBuffer[i].toString(16).padStart(2, '0');
          if (i === offset - start) hexStr += '<<<';
          if (i < contextBuffer.length - 1) hexStr += ' ';
        }
        console.log('Hex:', hexStr);
        
        // Try to find field boundaries
        console.log('\nAttempting to parse surrounding fields:');
        let pos = Math.max(0, offset - 20);
        for (let attempt = 0; attempt < 5 && pos < offset + 20 && pos < buffer.length; attempt++) {
          try {
            const fieldByte = buffer[pos];
            const fn = fieldByte >> 3;
            const wt = fieldByte & 0x07;
            console.log(`  Offset ${pos}: field=${fn}, wire=${wt}, byte=0x${fieldByte.toString(16)}`);
            
            // Skip field data
            if (wt === 0) { // varint
              pos++;
              while (pos < buffer.length && (buffer[pos] & 0x80)) pos++;
              pos++;
            } else if (wt === 1) { // 64-bit
              pos += 9;
            } else if (wt === 2) { // length-delimited
              pos++;
              let length = 0;
              let shift = 0;
              while (pos < buffer.length && (buffer[pos] & 0x80)) {
                length |= (buffer[pos] & 0x7f) << shift;
                shift += 7;
                pos++;
              }
              if (pos < buffer.length) {
                length |= buffer[pos] << shift;
                pos++;
              }
              pos += length;
            } else if (wt === 5) { // 32-bit
              pos += 5;
            } else {
              pos++; // unknown, skip byte
            }
          } catch (e) {
            pos++;
          }
        }
      }
    }
    
    // Attempt lenient decode using Reader
    console.log('\n🔄 Attempting lenient decode with Reader...');
    try {
      const cowMetrics = [];
      const reader = protobuf.Reader.create(buffer);
      
      // Read top-level MetricsData
      while (reader.pos < reader.len) {
        const tag = reader.uint32();
        const fieldNum = tag >>> 3;
        const wireType = tag & 7;

        if (fieldNum === 1 && wireType === 2) {
          // resourceMetrics field
          const rmLen = reader.uint32();
          const rmEnd = reader.pos + rmLen;
          
          // Parse ResourceMetrics
          while (reader.pos < rmEnd) {
            const rmTag = reader.uint32();
            const rmField = rmTag >>> 3;
            
            if (rmField === 2 && (rmTag & 7) === 2) {
              // scopeMetrics field
              const smLen = reader.uint32();
              const smEnd = reader.pos + smLen;
              
              // Parse ScopeMetrics
              while (reader.pos < smEnd) {
                const smTag = reader.uint32();
                const smField = smTag >>> 3;
                
                if (smField === 2 && (smTag & 7) === 2) {
                  // metrics field
                  const mLen = reader.uint32();
                  const mEnd = reader.pos + mLen;
                  
                  let metricName = null;
                  let metricType = null;
                  let temporality = null;
                  let histogramType = null;
                  let value = null;
                  
                  // Parse Metric with position tracking for better error recovery
                  while (reader.pos < mEnd) {
                    const startPos = reader.pos;
                    try {
                      const mTag = reader.uint32();
                      const mField = mTag >>> 3;
                      const mWire = mTag & 7;
                      
                      if (mField === 1 && mWire === 2) {
                        // name field
                        metricName = reader.string();
                      } else if (mField === 5 && mWire === 2) {
                        // gauge field (field 5 per OTLP spec)
                        metricType = 'gauge';
                        const gaugeLen = reader.uint32();
                        reader.skip(gaugeLen);
                        // Found metric data, skip to end to avoid reading other type fields
                        reader.pos = mEnd;
                        break;
                      } else if (mField === 7 && mWire === 2) {
                        // sum field (field 7 per OTLP spec)
                        metricType = 'sum';
                        const sumLen = reader.uint32();
                        const sumEnd = reader.pos + sumLen;
                        
                        while (reader.pos < sumEnd) {
                          try {
                            const sumTag = reader.uint32();
                            const sumField = sumTag >>> 3;
                            if (sumField === 1 && (sumTag & 7) === 2) {
                              // dataPoints
                              const dpLen = reader.uint32();
                              const dpEnd = reader.pos + dpLen;
                              while (reader.pos < dpEnd) {
                                try {
                                  const dpTag = reader.uint32();
                                  const dpField = dpTag >>> 3;
                                  if (dpField === 4 && (dpTag & 7) === 1) {
                                    value = reader.double();
                                  } else if (dpField === 6 && (dpTag & 7) === 0) {
                                    const temp = reader.uint32();
                                    temporality = temp === 1 ? 'DELTA' : temp === 2 ? 'CUMULATIVE' : 'UNSPECIFIED';
                                  } else {
                                    reader.skipType(dpTag & 7);
                                  }
                                } catch (e) { reader.pos = dpEnd; break; }
                              }
                            } else if (sumField === 2 && (sumTag & 7) === 0) {
                              const temp = reader.uint32();
                              temporality = temp === 1 ? 'DELTA' : temp === 2 ? 'CUMULATIVE' : 'UNSPECIFIED';
                            } else {
                              reader.skipType(sumTag & 7);
                            }
                          } catch (e) { reader.pos = sumEnd; break; }
                        }
                        // Found metric data, skip to end to avoid reading other type fields
                        reader.pos = mEnd;
                        break;
                      } else if (mField === 9 && mWire === 2) {
                        // histogram field (field 9 per OTLP spec)
                        metricType = 'histogram';
                        histogramType = 'explicit';
                        const histLen = reader.uint32();
                        const histEnd = reader.pos + histLen;
                        
                        while (reader.pos < histEnd) {
                          try {
                            const histTag = reader.uint32();
                            const histField = histTag >>> 3;
                            if (histField === 1 && (histTag & 7) === 2) {
                              // dataPoints
                              const dpLen = reader.uint32();
                              reader.skip(dpLen);
                            } else if (histField === 2 && (histTag & 7) === 0) {
                              const temp = reader.uint32();
                              temporality = temp === 1 ? 'DELTA' : temp === 2 ? 'CUMULATIVE' : 'UNSPECIFIED';
                            } else {
                              reader.skipType(histTag & 7);
                            }
                          } catch (e) { reader.pos = histEnd; break; }
                        }
                        // Found metric data, skip to end to avoid reading other type fields
                        reader.pos = mEnd;
                        break;
                      } else if (mField === 10 && mWire === 2) {
                        // exponential histogram field (field 10 per OTLP spec)
                        metricType = 'histogram';
                        histogramType = 'exponential';
                        const expLen = reader.uint32();
                        const expEnd = reader.pos + expLen;
                        
                        while (reader.pos < expEnd) {
                          try {
                            const expTag = reader.uint32();
                            const expField = expTag >>> 3;
                            if (expField === 1 && (expTag & 7) === 2) {
                              // dataPoints
                              const dpLen = reader.uint32();
                              reader.skip(dpLen);
                            } else if (expField === 2 && (expTag & 7) === 0) {
                              const temp = reader.uint32();
                              temporality = temp === 1 ? 'DELTA' : temp === 2 ? 'CUMULATIVE' : 'UNSPECIFIED';
                            } else {
                              reader.skipType(expTag & 7);
                            }
                          } catch (e) { reader.pos = expEnd; break; }
                        }
                        // Found metric data, skip to end to avoid reading other type fields
                        reader.pos = mEnd;
                        break;
                      } else {
                        // skip other fields gracefully
                        reader.skipType(mWire);
                      }
                    } catch (skipErr) {
                      // if skip fails, try to advance minimally and continue
                      if (reader.pos === startPos) {
                        reader.pos = Math.min(startPos + 1, mEnd);
                      }
                      if (reader.pos >= mEnd) break;
                    }
                  }
                  
                  if (metricName && metricName.toLowerCase().includes('cow')) {
                    cowMetrics.push({
                      name: metricName,
                      type: metricType,
                      temporality: temporality,
                      histogramType: histogramType,
                      value: value
                    });
                  }
                  
                  // Reset for next metric
                  metricName = null;
                  metricType = null;
                  temporality = null;
                  histogramType = null;
                  value = null;
                } else {
                  reader.skipType(smTag & 7);
                }
              }
            } else {
              reader.skipType(rmTag & 7);
            }
          }
        } else {
          reader.skipType(wireType);
        }
      }
      
      if (cowMetrics.length > 0) {
        console.log(`✅ Reader extracted ${cowMetrics.length} cow metric(s):`);
        cowMetrics.forEach(metric => {
          console.log(`\n  📊 ${metric.name}`);
          if (metric.type) console.log(`     Type: ${metric.type}`);
          if (metric.histogramType) console.log(`     Histogram: ${metric.histogramType}`);
          if (metric.temporality) console.log(`     Temporality: ${metric.temporality}`);
          if (metric.value !== null && metric.value !== undefined) console.log(`     Value: ${metric.value}`);
          
          // Show warning if incomplete
          if (!metric.type || !metric.temporality) {
            console.log(`     ⚠️ Incomplete data (parsing encountered errors)`);
          }
        });
      } else {
        console.log(`⚠️ Reader scan completed but found no cow metrics`);
      }
    } catch (readerError) {
      console.error(`❌ Reader scan failed: ${readerError.message}`);
    }
  }
  
  console.log('\n==========================================\n');
}

// OTLP Metrics endpoint
app.post('/v1/metrics', async (req, res) => {
  let buffer = req.body;
  const contentEncoding = req.headers['content-encoding'];
  
  console.log(`\n[OTLP-PROXY] Intercepted metrics request`);
  console.log(`  Content-Encoding: ${contentEncoding || 'none'}`);
  console.log(`  Size: ${buffer.length} bytes`);
  
  // Handle gzip compression
  if (contentEncoding === 'gzip') {
    try {
      console.log('[OTLP-PROXY] Decompressing gzip...');
      buffer = zlib.gunzipSync(buffer);
      console.log(`[OTLP-PROXY] Decompressed to ${buffer.length} bytes`);
    } catch (err) {
      console.error('[OTLP-PROXY] Gzip decompression failed:', err.message);
    }
  }
  
  // Parse protobuf
  logProtobufMetrics(buffer);
  
  // Forward to actual endpoint
  try {
    const forwardUrl = `${FORWARD_ENDPOINT}/v1/metrics`;
    const response = await axios.post(forwardUrl, req.body, {
      headers: req.headers,
      maxBodyLength: Infinity
    });
    res.status(response.status).send(response.data);
  } catch (error) {
    console.error(`[OTLP-PROXY] Forward failed: ${error.message}`);
    res.status(200).json({ status: 'logged' });
  }
});

// Passthrough for traces and logs
app.post('/v1/traces', async (req, res) => {
  try {
    const response = await axios.post(`${FORWARD_ENDPOINT}/v1/traces`, req.body, {
      headers: req.headers, maxBodyLength: Infinity
    });
    res.status(response.status).send(response.data);
  } catch (error) {
    res.status(200).json({ status: 'logged' });
  }
});

app.post('/v1/logs', async (req, res) => {
  try {
    const response = await axios.post(`${FORWARD_ENDPOINT}/v1/logs`, req.body, {
      headers: req.headers, maxBodyLength: Infinity
    });
    res.status(response.status).send(response.data);
  } catch (error) {
    res.status(200).json({ status: 'logged' });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', proxy: 'otlp-proxy', listening: PORT, forwarding: FORWARD_ENDPOINT });
});

app.get('/', (req, res) => {
  res.send(`OTLP Proxy running. Forwarding to ${FORWARD_ENDPOINT}`);
});

app.listen(PORT, () => {
  console.log(`[OTLP-PROXY] Server listening on port ${PORT}`);
  console.log(`[OTLP-PROXY] Forwarding metrics to ${FORWARD_ENDPOINT}`);
  console.log(`[OTLP-PROXY] Protobuf-only: Will log cow-related metrics`);
  console.log(`[OTLP-PROXY] Shows: name, value, temporality, histogram type`);
});
