#!/bin/bash

# Comprehensive failure simulation tests
API="http://localhost:3001"

echo "============================================"
echo "  Failure Simulation Tests"
echo "============================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Helper function to check event result
check_event_result() {
  local EVENT_ID=$1
  local EXPECTED_STATUS=$2
  local DESCRIPTION=$3
  
  sleep 2
  
  echo -e "Checking: ${BLUE}$DESCRIPTION${NC}"
  echo "Event ID: $EVENT_ID"
  
  RESPONSE=$(curl -s "$API/api/events/$EVENT_ID")
  STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | grep -o '[^"]*"$' | tr -d '"')
  ATTEMPTS=$(echo "$RESPONSE" | grep -o '"attempt_count":[0-9]*' | grep -o '[0-9]*$')
  
  echo "Status: $STATUS (Expected: $EXPECTED_STATUS)"
  echo "Attempts: $ATTEMPTS"
  
  if [ "$STATUS" = "$EXPECTED_STATUS" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
  else
    echo -e "${RED}✗ FAIL${NC}"
  fi
  echo ""
}

# -----------------------------------------------
# Test 1: Default (no simulate field)
# -----------------------------------------------
echo -e "${YELLOW}Test 1: Default (no simulate field) - Should succeed${NC}"
EVENT1="order-001"
curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$EVENT1\",
    \"type\":\"order.created\",
    \"data\":{
      \"orderId\":\"ORD-DEFAULT\"
    }
  }" > /dev/null
check_event_result "$EVENT1" "completed" "Default behavior (no simulate field)"

# -----------------------------------------------
# Test 2: simulate = "ok"
# -----------------------------------------------
echo -e "${YELLOW}Test 2: simulate = 'ok' - Should succeed immediately${NC}"
EVENT2="order-002"
curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$EVENT2\",
    \"type\":\"order.created\",
    \"data\":{
      \"orderId\":\"ORD-OK\",
      \"simulate\":\"ok\"
    }
  }" > /dev/null
check_event_result "$EVENT2" "completed" "Explicit 'ok' simulation"

# -----------------------------------------------
# Test 3: simulate = "slow:1"
# -----------------------------------------------
echo -e "${YELLOW}Test 3: simulate = 'slow:1' - Should take ~1 second${NC}"
EVENT3="order-003-slow-1sec"
START=$(date +%s)
curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$EVENT3\",
    \"type\":\"order.created\",
    \"data\":{
      \"orderId\":\"ORD-SLOW-1\",
      \"simulate\":\"slow:1\"
    }
  }" > /dev/null
check_event_result "$EVENT3" "completed" "Slow 1 second simulation"
END=$(date +%s)
DURATION=$((END - START))
echo "Actual duration: ~${DURATION}s"
echo ""

# -----------------------------------------------
# Test 4: simulate = "slow:3"
# -----------------------------------------------
echo -e "${YELLOW}Test 4: simulate = 'slow:3' - Should take ~3 seconds${NC}"
EVENT4="order-004-slow-3sec"
START=$(date +%s)
curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$EVENT4\",
    \"type\":\"order.created\",
    \"data\":{
      \"orderId\":\"ORD-SLOW-3\",
      \"simulate\":\"slow:3\"
    }
  }" > /dev/null

echo "Waiting 4 seconds for slow event to complete..."
sleep 4

RESPONSE=$(curl -s "$API/api/events/$EVENT4")
STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | grep -o '[^"]*"$' | tr -d '"')
echo "Status: $STATUS"
END=$(date +%s)
DURATION=$((END - START))
echo "Total duration: ~${DURATION}s (expected ~4-5s with 2s delay)"

if [ "$STATUS" = "completed" ]; then
  echo -e "${GREEN}✓ PASS${NC}"
else
  echo -e "${RED}✗ FAIL${NC}"
fi
echo ""

# -----------------------------------------------
# Test 5: simulate = "always_fail"
# -----------------------------------------------
echo -e "${YELLOW}Test 5: simulate = 'always_fail' - Should fail all attempts${NC}"
EVENT5="order-005-always-fail"
curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$EVENT5\",
    \"type\":\"order.created\",
    \"data\":{
      \"orderId\":\"ORD-ALWAYS-FAIL\",
      \"simulate\":\"always_fail\"
    }
  }" > /dev/null

echo "Waiting 70 seconds for all retries to exhaust..."
for i in {1..70}; do
  if [ $((i % 10)) -eq 0 ]; then 
    echo -n "${i}s "
  else
    echo -n "."
  fi
  sleep 1
done
echo ""

RESPONSE=$(curl -s "$API/api/events/$EVENT5")
STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | grep -o '[^"]*"$' | tr -d '"')
ATTEMPTS=$(echo "$RESPONSE" | grep -o '"attempt_count":[0-9]*' | grep -o '[0-9]*$')

echo "Status: $STATUS (Expected: failed)"
echo "Attempts: $ATTEMPTS (Expected: 5 or more)"

if [ "$STATUS" = "failed" ]; then
  echo -e "${GREEN}✓ PASS${NC}"
else
  echo -e "${RED}✗ FAIL${NC}"
fi
echo ""

# -----------------------------------------------
# Test 6: simulate = "fail_then_succeed:1"
# -----------------------------------------------
echo -e "${YELLOW}Test 6: simulate = 'fail_then_succeed:1' - Fail once, then succeed${NC}"
EVENT6="order-006-fail-once"
curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$EVENT6\",
    \"type\":\"order.created\",
    \"data\":{
      \"orderId\":\"ORD-FAIL-SUCCEED-1\",
      \"simulate\":\"fail_then_succeed:1\"
    }
  }" > /dev/null

echo "Waiting 5 seconds for retry..."
sleep 5

RESPONSE=$(curl -s "$API/api/events/$EVENT6")
STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | grep -o '[^"]*"$' | tr -d '"')
ATTEMPTS=$(echo "$RESPONSE" | grep -o '"attempt_count":[0-9]*' | grep -o '[0-9]*$')
ATTEMPTS_DATA=$(echo "$RESPONSE" | grep -o '"attempt_number":[0-9]*' | wc -l)

echo "Status: $STATUS (Expected: completed)"
echo "Attempt count: $ATTEMPTS"
echo "Total attempts recorded: $ATTEMPTS_DATA"

if [ "$STATUS" = "completed" ] && [ "$ATTEMPTS_DATA" -eq 2 ]; then
  echo -e "${GREEN}✓ PASS${NC}"
else
  echo -e "${RED}✗ FAIL${NC}"
fi
echo ""

# -----------------------------------------------
# Test 7: simulate = "fail_then_succeed:3"
# -----------------------------------------------
echo -e "${YELLOW}Test 7: simulate = 'fail_then_succeed:3' - Fail 3 times, then succeed${NC}"
EVENT7="order-007-fail-thrice"
curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$EVENT7\",
    \"type\":\"order.created\",
    \"data\":{
      \"orderId\":\"ORD-FAIL-SUCCEED-3\",
      \"simulate\":\"fail_then_succeed:3\"
    }
  }" > /dev/null

echo "Waiting 20 seconds for retries (2s + 4s + 8s)..."
for i in {1..20}; do
  echo -n "."
  sleep 1
done
echo ""

RESPONSE=$(curl -s "$API/api/events/$EVENT7")
STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | grep -o '[^"]*"$' | tr -d '"')
ATTEMPTS=$(echo "$RESPONSE" | grep -o '"attempt_count":[0-9]*' | grep -o '[0-9]*$')
ATTEMPTS_DATA=$(echo "$RESPONSE" | grep -o '"attempt_number":[0-9]*' | wc -l)

echo "Status: $STATUS (Expected: completed)"
echo "Attempt count: $ATTEMPTS"
echo "Total attempts recorded: $ATTEMPTS_DATA (Expected: 4 - fail, fail, fail, succeed)"

if [ "$STATUS" = "completed" ] && [ "$ATTEMPTS_DATA" -eq 4 ]; then
  echo -e "${GREEN}✓ PASS${NC}"
else
  echo -e "${RED}✗ FAIL${NC}"
fi
echo ""

# -----------------------------------------------
# Test 8: Edge case - empty simulate field
# -----------------------------------------------
echo -e "${YELLOW}Test 8: Edge case - empty simulate field ('') - Should succeed${NC}"
EVENT8="order-008-empty-simulate"
curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$EVENT8\",
    \"type\":\"order.created\",
    \"data\":{
      \"orderId\":\"ORD-EMPTY-SIM\",
      \"simulate\":\"\"
    }
  }" > /dev/null
check_event_result "$EVENT8" "completed" "Empty simulate field (should default to ok)"

# -----------------------------------------------
# Test 9: Edge case - invalid simulate format
# -----------------------------------------------
echo -e "${YELLOW}Test 9: Edge case - invalid simulate format - Should succeed (default to ok)${NC}"
EVENT9="order-009-invalid-simulate"
curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$EVENT9\",
    \"type\":\"order.created\",
    \"data\":{
      \"orderId\":\"ORD-INVALID-SIM\",
      \"simulate\":\"invalid_format_xyz\"
    }
  }" > /dev/null
check_event_result "$EVENT9" "completed" "Invalid simulate format (should default to ok)"

# -----------------------------------------------
# Test 10: Edge case - slow:0
# -----------------------------------------------
echo -e "${YELLOW}Test 10: Edge case - slow:0 - Should succeed immediately${NC}"
EVENT10="order-010-slow-0sec"
curl -s -X POST "$API/webhooks" \
  -H "Content-Type: application/json" \
  -d "{
    \"eventId\":\"$EVENT10\",
    \"type\":\"order.created\",
    \"data\":{
      \"orderId\":\"ORD-SLOW-0\",
      \"simulate\":\"slow:0\"
    }
  }" > /dev/null
check_event_result "$EVENT10" "completed" "Slow 0 seconds (should complete immediately)"

# -----------------------------------------------
# Summary
# -----------------------------------------------
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Getting event statistics..."
curl -s "$API/api/stats" | grep -o '"[a-zA-Z_]*":"[^"]*"'
echo ""
echo -e "${GREEN}All failure simulation scenarios tested!${NC}"
