/*******************************************************************************
 * Copyright 2008-2013 by Aerospike.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 ******************************************************************************/
#include "benchmark.h"
#include <pthread.h>
#include <citrusleaf/cf_clock.h>

static void*
ticker_worker(void* udata)
{
	clientdata* data = (clientdata*)udata;
	latency* write_latency = &data->write_latency;
	bool latency = data->latency;
	char latency_header[512];
	char latency_detail[512];
	
	uint64_t prev_time = cf_getms();
	
	if (latency) {
		latency_set_header(write_latency, latency_header);
	}
	sleep(1);
	
	while (data->valid) {
		uint64_t time = cf_getms();
		int64_t elapsed = time - prev_time;
		prev_time = time;

		int32_t write_current = cf_atomic32_fas_m(&data->write_count, 0);
		int32_t write_timeout_current = cf_atomic32_fas_m(&data->write_timeout_count, 0);
		int32_t write_error_current = cf_atomic32_fas_m(&data->write_error_count, 0);
		int32_t total_count = data->current_key;
		int32_t write_tps = (int32_t)((double)write_current * 1000 / elapsed + 0.5);
			
		blog_info("write(tps=%d timeouts=%d errors=%d total=%d)",
			write_tps, write_timeout_current, write_error_current, total_count);
		
		if (latency) {
			blog_line("%s", latency_header);
			latency_print_results(write_latency, "write", latency_detail);
			blog_line("%s", latency_detail);
		}
		
		if (write_timeout_current + write_error_current > 10) {
			if (is_stop_writes(&data->client, data->host, data->port, data->namespace)) {
				if (data->valid) {
					blog_error("Server is currently in readonly mode. Shutting down...");
					data->valid = false;
					continue;
				}
			}
		}
		sleep(1);
	}
	return 0;
}

static void*
linear_write_worker(void* udata)
{
	clientdata* data = (clientdata*)udata;
	int32_t records = data->records;
	int32_t key;
	
	while (data->valid) {
		key = cf_atomic32_incr(&data->current_key);
		
		if (key > records) {
			if (key - 1 == records) {
				blog_info("write(tps=%d timeouts=%d errors=%d total=%d)",
					cf_atomic32_get(data->write_count),
					cf_atomic32_get(data->write_timeout_count),
					cf_atomic32_get(data->write_error_count),
					records);
			}
			break;
		}
		write_record(key, data);
	}
	return 0;
}

int
linear_write(clientdata* data)
{
	blog_info("Initialize %d records", data->records);
	
	pthread_t ticker;
	if (pthread_create(&ticker, 0, ticker_worker, data) != 0) {
		data->valid = false;
		blog_error("Failed to create thread.");
		return -1;
	}
	
	int max = data->threads;
	blog_info("Start %d generator threads", max);
	pthread_t threads[max];
	
	for (int i = 0; i < max; i++) {
		if (pthread_create(&threads[i], 0, linear_write_worker, data) != 0) {
			data->valid = false;
			blog_error("Failed to create thread.");
			return -1;
		}
	}
	
	for (int i = 0; i < max; i++) {
		pthread_join(threads[i], 0);
	}
	
	data->valid = false;
	pthread_join(ticker, 0);
	return 0;
}
