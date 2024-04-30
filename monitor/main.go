package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand/v2"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

var endpoint string
var comparatorEndpoint string
var metricsAPIKey string
var metricsURL string

const tuvaluBounds = "32.1605002739009,-65.01915229014634,32.51034078213685,-64.45541632823227"

const minInitialDelay = 5 * time.Minute
const maxDelayOffsetSecs = 60
const delay = 15 * time.Minute

func main() {
	endpoint = os.Getenv("ENDPOINT")
	if endpoint == "" {
		panic("ENDPOINT is required")
	}
	comparatorEndpoint = os.Getenv("COMPARATOR_ENDPOINT")
	if comparatorEndpoint == "" {
		panic("COMPARATOR_ENDPOINT is required")
	}
	metricsAPIKey = os.Getenv("METRICS_API_KEY")
	if metricsAPIKey == "" {
		panic("METRICS_API_KEY is required")
	}
	metricsURL = os.Getenv("METRICS_URL")
	if metricsURL == "" {
		panic("METRICS_URL is required")
	}

	initialDelay := minInitialDelay + time.Duration(rand.IntN(maxDelayOffsetSecs))*time.Second
	log.Printf("waiting %s before starting", initialDelay)
	time.Sleep(initialDelay)

	for i := 0; ; i++ {
		if i > 0 {
			log.Printf("waiting %s", delay)
			time.Sleep(delay)
		}

		metrics, err := scrapeMetrics()
		if err != nil {
			log.Printf("error scraping metrics: %v", err)
			continue
		}
		log.Printf("metrics: %+v", metrics)

		if err := sendMetrics(metrics); err != nil {
			log.Printf("error sending metrics: %v", err)
			continue
		}
	}
}

func scrapeMetrics() (metrics []string, err error) {
	countTuvaluQuery := fmt.Sprintf("[out:json];\n(\n  area(%s);\n  nwr(%s);\n);\nout count;", tuvaluBounds, tuvaluBounds)

	endpointResp, err := queryOneTags(endpoint, countTuvaluQuery)
	if err != nil {
		return nil, fmt.Errorf("querying endpoint: %w", err)
	}

	comparatorResp, err := queryOneTags(comparatorEndpoint, countTuvaluQuery)
	if err != nil {
		return nil, fmt.Errorf("querying comparator: %w", err)
	}

	for k, _ := range endpointResp {
		eVal, err := strconv.ParseInt(endpointResp[k], 10, 64)
		if err != nil {
			return nil, fmt.Errorf("parsing endpoint value: %w", err)
		}
		cVal, err := strconv.ParseInt(comparatorResp[k], 10, 64)
		if err != nil {
			return nil, fmt.Errorf("parsing comparator value: %w", err)
		}

		metrics = append(metrics, fmt.Sprintf("overpass,region=tuvalu,type=%s count_check=%d", k, eVal))
		metrics = append(metrics, fmt.Sprintf("overpass,region=tuvalu,type=%s count_lag_check=%d", k, cVal-eVal))
	}

	return metrics, nil
}

func sendMetrics(metrics []string) error {
	req, err := http.NewRequest("POST", metricsURL, strings.NewReader(strings.Join(metrics, "\n")))
	if err != nil {
		panic(err)
	}
	req.Header.Set("Content-Type", "text/plain")
	req.Header.Set("Authorization", "Bearer "+metricsAPIKey)
	req.Header.Set("User-Agent", "github.com/dzfranklin/overpass-infra/monitor")
	client := &http.Client{}
	resp, err := client.Do(req)

	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		respBody, err := io.ReadAll(resp.Body)
		if err != nil {
			return fmt.Errorf("status code %d", resp.StatusCode)
		} else {
			return fmt.Errorf("status code %d: %s", resp.StatusCode, string(respBody))
		}
	}
	log.Printf("sent metrics")
	return nil
}

func queryOneTags(endpoint string, query string) (map[string]string, error) {
	log.Printf("querying %s", endpoint)
	resp, err := http.Post(endpoint+"/interpreter", "text/plain", strings.NewReader(query))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("status code %d", resp.StatusCode)
	}

	var container struct {
		Elements []struct {
			Tags map[string]string `json:"tags"`
		} `json:"elements"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&container); err != nil {
		return nil, err
	}

	if len(container.Elements) == 0 {
		return nil, fmt.Errorf("no elements, expected one")
	}
	if len(container.Elements) > 1 {
		return nil, fmt.Errorf("multiple elements, expected one")
	}

	return container.Elements[0].Tags, nil
}
