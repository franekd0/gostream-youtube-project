package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHelloEndpoint(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/api/hello", nil)
	recorder := httptest.NewRecorder()
	newHandler().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusOK)
	}

	var body map[string]string
	if err := json.NewDecoder(recorder.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if got := body["message"]; got != "Hello from Go!" {
		t.Errorf("message = %q, want %q", got, "Hello from Go!")
	}
}
