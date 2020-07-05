package main

import (
	"context"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"
)

func main() {
	mux := http.NewServeMux()

	// Registering handler
	mux.HandleFunc("/", fibonacciHandler)
	mux.HandleFunc("/health", healthCheckHandler)

	srv := &http.Server{
		Handler:      mux,
		Addr:         ":8080",
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
	}

	// Start Server
	go func() {
		log.Println("Starting Server")
		if err := srv.ListenAndServe(); err != nil {
			log.Fatal(err)
		}
	}()

	// Graceful Shutdown
	waitForShutdown(srv)
}

func healthCheckHandler(writer http.ResponseWriter, request *http.Request) {
	writer.WriteHeader(http.StatusOK)
}

func fibonacciHandler(writer http.ResponseWriter, request *http.Request) {
	query := request.URL.Query()
	computeQryParam := query.Get("compute")
	if computeQryParam == "" {
		http.Error(writer, "Please provide the nth value via '?compute=' query parameter.",
			http.StatusBadRequest)
		return
	}

	pos, err := strconv.Atoi(computeQryParam)
	if err != nil {
		http.Error(writer, fmt.Sprintf("Please provide a valid nth value. Invalid input %v", computeQryParam),
			http.StatusBadRequest)
		return
	}

	result := fibonacci(int64(pos))
	_, err = writer.Write([]byte(fmt.Sprintf("The %vth term in Fibonacci Sequence is %v\n", pos, result)))
	if err != nil {
		http.Error(writer, http.StatusText(http.StatusInternalServerError),
			http.StatusInternalServerError)
		return
	}
}

func fibonacci(n int64) *big.Int {
	log.Printf("Computing %vth term in Fibonacci Sequence.", n)
	// Initialize two big ints with the first two numbers in the sequence.
	a := big.NewInt(0)
	b := big.NewInt(1)

	// Initialize limit as 10^99, the smallest integer with 100 digits.
	var limit big.Int
	limit.Exp(big.NewInt(10), big.NewInt(99), nil)

	// Loop while a is smaller than 1e100 or User intended maximum.
	for a.Cmp(&limit) < 0 && n > 0 {
		// Compute the next Fibonacci number, storing it in a.
		a.Add(a, b)
		// Swap a and b so that b is the next number in the sequence.
		a, b = b, a
		// Decrease counter
		n--
	}
	return a
}

func waitForShutdown(srv *http.Server) {
	interruptChan := make(chan os.Signal, 1)
	signal.Notify(interruptChan, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

	// Block until we receive our signal.
	<-interruptChan

	// Create a deadline to wait for.
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*3)
	defer cancel()
	srv.Shutdown(ctx)

	log.Println("Shutting down")
	os.Exit(0)
}
