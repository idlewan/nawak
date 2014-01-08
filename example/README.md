## Performance test
If you want to make changes and see how it performs, you can use wrk to have a preview of the performance.
From the web frameworks benchmarks :

    wrk -H 'Host: localhost' -H 'Accept: application/json,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7' -H 'Connection: keep-alive' -d 15 -c 256 -t 1 http://localhost:6767/json
