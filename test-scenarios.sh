#!/bin/bash

# Comprehensive test scenarios for webhook processor
API="http://localhost:3001"

echo "============================================"
echo "  Webhook Processor — Test Scenarios"
echo "============================================"
echo ""

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# -----------------------------------------------
# Scenario 1: Create quick events
# -----------------------------------------------
echo -e "${BLUE}--- Scenario 1: Quick Events (Immediate Completion) ---${NC}"
echo "Creating 3 quick events that complete immediately..."
echo ""

for i in {1..3}; do
  EVENT_ID="order-quick-$i"
  echo "Creating event: $EVENT_ID"
  curl -s -X POST "$API/webhooks" \
    -H "Content-Type: application/json" \
    -d "{
      \"eventId\":\"$EVENT_ID\",
      \"type\":\"order.created\",
      \"data\":{
        \"orderId\":\"ORD-QUICK-$i\",
        \"customerId\":\"CUS-$i\",
        \"simulate\":\"ok\"
      }
    }" | grep -o '"accepted":true' && echo "✓ Created" || echo "✗ Failed"
done
echo ""
echo "Waiting 3 seconds for processing..."
sleep 3
echo ""

# -----------------------------------------------
# Scenario 2: Check all events
# -----------------------------------------------
echo -e "${BLUE}--- Scenario 2: Check All Events ---${NC}"
echo "All events with their status and worker assignment:"
echo ""
curl -s "$API/api/events" | grep -o '"event_id":"[^"]*"\|"status":"[^"]*"\|"worker_name":"[^"]*"\|"worker_name":null' | head -30
echo ""
echo ""

# -----------------------------------------------
# Scenario 3: Slow event
# -----------------------------------------------
echo -e "${BLUE}--- Scenario 3: Slow Event (5 seconds) ---${NC}"
SLOW_EVENT="order-slow-5sec"
echo "Creating slow event: $SLOW_EVENT"
curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$SLOW_EVENT\",
    \"type\":\"order.created\",
    \"data\":{
      \"orderId\":\"ORD-SLOW-001\",
      \"simulate\":\"slow:5\"
    }
  }" | grep -o '"accepted":true' && echo "✓ Created" || echo "✗ Failed"
echo ""
echo "Event should be locked by a worker for ~5 seconds"
echo "Checking worker assignment in 2 seconds..."
sleep 2
echo "Currently processing events:"
curl -s "$API/api/events" | grep -o '"event_id":"[^"]*"\|"status":"processing"\|"worker_name":"[^"]*"' | grep -A1 -B1 "processing"
echo ""
echo ""

# -----------------------------------------------
# Scenario 4: Fail then succeed
# -----------------------------------------------
echo -e "${BLUE}--- Scenario 4: Fail Then Succeed (2 failures, then success) ---${NC}"
FAIL_EVENT="order-fail-then-success"
echo "Creating event that fails 2 times then succeeds: $FAIL_EVENT"
curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$FAIL_EVENT\",
    \"type\":\"order.created\",
    \"data\":{
      \"orderId\":\"ORD-FAIL-SUCCEED\",
      \"simulate\":\"fail_then_succeed:2\"
    }
  }" | grep -o '"accepted":true' && echo "✓ Created" || echo "✗ Failed"
echo ""
echo "This event will retry with backoff (2s, 4s, 8s...)"
echo "Waiting 20 seconds for retries to complete..."
for i in {1..20}; do
  echo -n "."
  sleep 1
done
echo ""
echo "Checking event status and attempt history:"
curl -s "$API/api/events/$FAIL_EVENT" 2>/dev/null | grep -o '"status":"[^"]*"\|"attempt_count":[0-9]*\|"attempt_number":[0-9]*\|"result":"[^"]*"' | head -10
echo ""
echo ""

# -----------------------------------------------
# Scenario 5: Permanent failure
# -----------------------------------------------
echo -e "${BLUE}--- Scenario 5: Permanent Failure (Always fails) ---${NC}"
FAIL_EVENT="order-always-fail"
echo "Creating event that always fails: $FAIL_EVENT"
curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$FAIL_EVENT\",
    \"type\":\"order.created\",
    \"data\":{
      \"orderId\":\"ORD-PERM-FAIL\",
      \"simulate\":\"always_fail\"
    }
  }" | grep -o '"accepted":true' && echo "✓ Created" || echo "✗ Failed"
echo ""
echo "Waiting 70 seconds for all retries to exhaust (max 5 attempts with backoff)..."
for i in {1..70}; do
  echo -n "."
  if [ $((i % 10)) -eq 0 ]; then echo -n " ${i}s"; fi
  sleep 1
done
echo ""
echo "Event status after all retries:"
curl -s "$API/api/events/$FAIL_EVENT" | grep -o '"status":"[^"]*"\|"attempt_count":[0-9]*'
echo ""
echo ""

# -----------------------------------------------
# Scenario 6: Duplicate submission
# -----------------------------------------------
echo -e "${BLUE}--- Scenario 6: Duplicate Submission ---${NC}"
DUP_EVENT="order-duplicate-test"
echo "Creating event: $DUP_EVENT"
RESPONSE1=$(curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$DUP_EVENT\",
    \"type\":\"order.created\",
    \"data\":{\"orderId\":\"ORD-DUP\"}
  }")
echo "First submission: $(echo $RESPONSE1 | grep -o '"duplicate":false' || echo 'new event')"

echo "Sending same event again..."
RESPONSE2=$(curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$DUP_EVENT\",
    \"type\":\"order.created\",
    \"data\":{\"orderId\":\"ORD-DUP\"}
  }")
echo "Second submission: $(echo $RESPONSE2 | grep -o '"duplicate":true' || echo 'should be duplicate')"
echo ""
echo ""

# -----------------------------------------------
# Scenario 7: Stats summary
# -----------------------------------------------
echo -e "${BLUE}--- Scenario 7: Overall Stats ---${NC}"
echo "System statistics:"
curl -s "$API/api/stats" | grep -o '"[a-zA-Z_]*":"[^"]*"' | head -10
echo ""
echo ""

# -----------------------------------------------
# Scenario 8: Events by status
# -----------------------------------------------
echo -e "${BLUE}--- Scenario 8: Events Summary ---${NC}"
echo "Summary of all events:"
echo ""
echo "Total events in database:"
curl -s "$API/api/events" | grep -o '"event_id"' | wc -l
echo ""
echo "Completed events:"
curl -s "$API/api/events" | grep -o '"status":"completed"' | wc -l
echo ""
echo "Failed events:"
curl -s "$API/api/events" | grep -o '"status":"failed"' | wc -l
echo ""
echo "Pending events:"
curl -s "$API/api/events" | grep -o '"status":"pending"' | wc -l
echo ""
echo "Processing events:"
curl -s "$API/api/events" | grep -o '"status":"processing"' | wc -l
echo ""

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Test Scenarios Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
