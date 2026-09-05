#!/bin/bash

# Simple curl examples with readable event IDs
# Copy and paste these commands to test the webhook processor

API="http://localhost:3001"

echo "============================================"
echo "  Simple Webhook Examples"
echo "============================================"
echo ""

# -----------------------------------------------
# Example 1: Simple success
# -----------------------------------------------
echo "1. Create a simple order (succeeds immediately):"
echo ""
echo "curl -X POST $API/webhooks \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{"
echo "    \"eventId\": \"order-123\","
echo "    \"type\": \"order.created\","
echo "    \"data\": {"
echo "      \"orderId\": \"ORD-123\","
echo "      \"customerId\": \"CUS-A\""
echo "    }"
echo "  }'"
echo ""

# -----------------------------------------------
# Example 2: Slow order (takes time)
# -----------------------------------------------
echo "2. Create an order that takes 5 seconds to process:"
echo ""
echo "curl -X POST $API/webhooks \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{"
echo "    \"eventId\": \"order-124\","
echo "    \"type\": \"order.created\","
echo "    \"data\": {"
echo "      \"orderId\": \"ORD-124\","
echo "      \"customerId\": \"CUS-B\","
echo "      \"simulate\": \"slow:5\""
echo "    }"
echo "  }'"
echo ""

# -----------------------------------------------
# Example 3: Order that fails then succeeds
# -----------------------------------------------
echo "3. Create an order that fails 2 times, then succeeds:"
echo ""
echo "curl -X POST $API/webhooks \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{"
echo "    \"eventId\": \"order-125\","
echo "    \"type\": \"order.created\","
echo "    \"data\": {"
echo "      \"orderId\": \"ORD-125\","
echo "      \"customerId\": \"CUS-C\","
echo "      \"simulate\": \"fail_then_succeed:2\""
echo "    }"
echo "  }'"
echo ""

# -----------------------------------------------
# Example 4: Order that always fails
# -----------------------------------------------
echo "4. Create an order that always fails:"
echo ""
echo "curl -X POST $API/webhooks \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{"
echo "    \"eventId\": \"order-126\","
echo "    \"type\": \"order.created\","
echo "    \"data\": {"
echo "      \"orderId\": \"ORD-126\","
echo "      \"customerId\": \"CUS-D\","
echo "      \"simulate\": \"always_fail\""
echo "    }"
echo "  }'"
echo ""

# -----------------------------------------------
# Check events
# -----------------------------------------------
echo "5. Check all events:"
echo ""
echo "curl $API/api/events | jq '.[] | {event_id, status, worker: .worker_name}'"
echo ""

# -----------------------------------------------
# Check specific event
# -----------------------------------------------
echo "6. Check specific event (replace EVENT_ID with actual ID):"
echo ""
echo "curl $API/api/events/order-123"
echo ""

# -----------------------------------------------
# Check stats
# -----------------------------------------------
echo "7. Get system stats:"
echo ""
echo "curl $API/api/stats"
echo ""

echo "============================================"
