# Istio Assignment

### Prerequisite

- MetalLB should be configured 
  Ref : [MetalLB](https://metallb.universe.tf/installation/)
- The [online-boutique](https://github.com/ppratheesh/online-boutique) Application should be deployed in the cluster
- Istio injection should be enabled in the namespace - [sidecar-injection](https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/)


#### Tasks
1: Gateways:
Expose the frontend service of the application using the Istio-ingress gateway.
The host to be used is "onlineboutique.example.com" for the Ingress gateway. Any other host's requests should be rejected by the gateway.

Istio Gateway manifest

```
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: frontend-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
    - hosts:
        - "onlineboutique.example.com"
      port:
        name: http
        number: 80
        protocol: HTTP

```
For routing the traffic from Gateway to the frontend service created virtual service as below 

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend-vs
spec:
  hosts:
    - "onlineboutique.example.com"
  gateways:
    - frontend-gateway
  http:
    - route:
        - destination:
            host: frontend
            port:
              number: 80
```
Test:

Find the external ip for the Istio ingressgateway service 

```console
pratheesh@PF3HLE8F:/home/prateesh/Tasks/Istio/online-boutique/task1$ curl -s -HHost:onlineboutique.example.com   http://172.18.255.230  -o /dev/null -v
*   Trying 172.18.255.230:80...
* TCP_NODELAY set
* Connected to 172.18.255.230 (172.18.255.230) port 80 (#0)
> GET / HTTP/1.1
> Host:onlineboutique.example.com
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< set-cookie: shop_session-id=f0ba821e-51c6-4cc8-ab37-16528bbb4511; Max-Age=172800
< date: Tue, 18 Oct 2022 06:50:09 GMT
< content-type: text/html; charset=utf-8
< x-envoy-upstream-service-time: 11165
< server: istio-envoy
< transfer-encoding: chunked
< 
{ [6975 bytes data]
* Connection #0 to host 172.18.255.230 left intact
pratheesh@PF3HLE8F:/home/prateesh/Tasks/Istio/online-boutique/task1$ curl -s -HHost:demo.example.com   http://172.18.255.230  -o /dev/null -v
*   Trying 172.18.255.230:80...
* TCP_NODELAY set
* Connected to 172.18.255.230 (172.18.255.230) port 80 (#0)
> GET / HTTP/1.1
> Host:demo.example.com
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 404 Not Found
< date: Tue, 18 Oct 2022 06:50:19 GMT
< server: istio-envoy
< content-length: 0
< 
* Connection #0 to host 172.18.255.230 left intact
pratheesh@PF3HLE8F:/home/prateesh/Tasks/Istio/online-boutique/task1$ curl -s -HHost:example.domain.com   http://172.18.255.230  -o /dev/null -v
*   Trying 172.18.255.230:80...
* TCP_NODELAY set
* Connected to 172.18.255.230 (172.18.255.230) port 80 (#0)
> GET / HTTP/1.1
> Host:example.domain.com
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 404 Not Found
< date: Tue, 18 Oct 2022 06:50:47 GMT
< server: istio-envoy
< content-length: 0
< 
* Connection #0 to host 172.18.255.230 left intact

```

2: Traffic routing:
Split the traffic between the frontend and frontend-v2 service by 50%.
The way to verify that this works is when 50% of the requests would show the landing page banner as "Free shipping with $100 purchase!" vs "Free shipping with $75 purchase!"

create the following DestinationRule

```
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: frontend-ds
spec:
  host: frontend
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
```
To Split traffic modify the  VirtualService as follows:

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend-vs
spec:
  hosts:
    - "onlineboutique.example.com"
  gateways:
    - frontend-gateway
  http:
    - route:
        - destination:
            host: frontend
            subset: v1
          weight: 50
        - destination:
            host: frontend
            subset: v2
          weight: 50
```
Test:

```console
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com  http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $100 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com  http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $75 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com  http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $75 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com  http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $100 purchase! &nbsp;&nbsp;</div>

```
3: Traffic Routing:
Route traffic to the based on the browser being used.
When you use Firefox the Gateway routes to the frontend service whereas it routes to the frontend-v2 pods if it is accessed via Chrome.
Hint: use the user-agent HTTP header added by the browser.

Modify virtual service to route based on browser using user-agent headers

Ref: [Request based routing](https://iwconnect.com/request-based-routing-in-kubernetes-using-istio/)

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend-vs
spec:
  hosts:
    - "onlineboutique.example.com"
  gateways:
    - frontend-gateway
  http:
    - match:
       - headers:
            user-agent:
               regex: '.*Firefox.*'
      route:
        - destination:
            host: frontend
            subset: v1

    - match:
       - headers:
           user-agent:
               regex: '.*Chrome.*'
      route:
        - destination:
            host: frontend
            subset: v2

    - route:
        - destination:
            host: frontend
            subset: v1
          weight: 50
        - destination:
            host: frontend
            subset: v2
          weight: 50
```
Test:

FireFox:
```
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:105.0) Gecko/20100101 Firefox/105.0" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $75 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:105.0) Gecko/20100101 Firefox/105.0" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $75 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:105.0) Gecko/20100101 Firefox/105.0" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $75 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:105.0) Gecko/20100101 Firefox/105.0" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $75 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:105.0) Gecko/20100101 Firefox/105.0" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $75 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:105.0) Gecko/20100101 Firefox/105.0" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $75 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:105.0) Gecko/20100101 Firefox/105.0" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $75 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:105.0) Gecko/20100101 Firefox/105.0" http://172.18.255.230 | grep -i "free shipping"
^[[                <div class="h-free-shipping">Free shipping with $75 purchase! &nbsp;&nbsp;</div>

```
Chrome:

```console
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $100 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $100 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $100 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $100 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $100 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $100 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $100 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $100 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $100 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $100 purchase! &nbsp;&nbsp;</div>
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" http://172.18.255.230 | grep -i "free shipping"
                <div class="h-free-shipping">Free shipping with $100 purchase! &nbsp;&nbsp;</div>


```

4. Timeout:
This is a slightly different lab. You need to tighten the boundaries of acceptable latency in this lab.
Delete the productcatalogservice. There is a lot of latency between the frontend and the productcatalogv2 service. add a timeout of 3s. (You need to produce a 504 Gateway timeout error).

Delete the productcatalogservice deployment

Add timeout in virtual service

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend-vs
spec:
  hosts:
    - "onlineboutique.example.com"
  gateways:
    - frontend-gateway
  http:
    - match:
       - headers:
            user-agent:
               regex: '.*Firefox.*'
      route:
        - destination:
            host: frontend
            subset: v1
      timeout: 3s
    - match:
       - headers:
           user-agent:
               regex: '.*Chrome.*'
      route:
        - destination:
            host: frontend
            subset: v2
      timeout: 3s
    - route:
        - destination:
            host: frontend
            subset: v1
          weight: 50
        - destination:
            host: frontend
            subset: v2
          weight: 50
      timeout: 3s  
```

Test:

```console
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com http://172.18.255.230 -o /dev/null -v
*   Trying 172.18.255.230:80...
* TCP_NODELAY set
* Connected to 172.18.255.230 (172.18.255.230) port 80 (#0)
> GET / HTTP/1.1
> Host:onlineboutique.example.com
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 504 Gateway Timeout
< content-length: 24
< content-type: text/plain
< date: Tue, 18 Oct 2022 07:39:09 GMT
< server: istio-envoy
< 
{ [24 bytes data]
* Connection #0 to host 172.18.255.230 left intact
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com http://172.18.255.230 -o /dev/null -v
*   Trying 172.18.255.230:80...
* TCP_NODELAY set
* Connected to 172.18.255.230 (172.18.255.230) port 80 (#0)
> GET / HTTP/1.1
> Host:onlineboutique.example.com
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 504 Gateway Timeout
< content-length: 24
< content-type: text/plain
< date: Tue, 18 Oct 2022 07:40:39 GMT
< server: istio-envoy
< 
{ [24 bytes data]
* Connection #0 to host 172.18.255.230 left intact
pratheesh@PF3HLE8F:~$ curl -s -HHost:onlineboutique.example.com http://172.18.255.230 -o /dev/null -v
*   Trying 172.18.255.230:80...
* TCP_NODELAY set
* Connected to 172.18.255.230 (172.18.255.230) port 80 (#0)
> GET / HTTP/1.1
> Host:onlineboutique.example.com
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 504 Gateway Timeout
< content-length: 24
< content-type: text/plain
< date: Tue, 18 Oct 2022 07:40:44 GMT
< server: istio-envoy
< 
{ [24 bytes data]
* Connection #0 to host 172.18.255.230 left intact

```

5. TLS:
Setup a TLS ingress gateway for the frontend service. Generate self signed certificates and add them to the Ingress Gateway for TLS communication.

- Create a root certificate and private key to sign the certificates using following command
```
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=example Inc./CN=example.com' -keyout example.com.key -out example.com.crt
```

- Create a csr certificate and a private key for onlineboutique.example.com

```
openssl req -out onlineboutique.example.com.csr -newkey rsa:2048 -nodes -keyout onlineboutique.example.com.key -subj "/CN=onlineboutique.example.com/O=demo organization"
```
- Sign the csr using root ca and root key

```
openssl x509 -req -sha256 -days 365 -CA example.com.crt -CAkey example.com.key -set_serial 0 -in onlineboutique.example.com.csr -out onlineboutique.example.com.crt
```

Create a kubernetes secrets object for the cert and key

```console
kubectl create -n istio-system secret tls onlineboutique-credential --key=onlineboutique.example.com.key  --cert=onlineboutique.example.com.crt
```

Modfify gateway to use ssl

```
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: frontend-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
    - hosts:
        - "onlineboutique.example.com"
      port:
        name: https
        number: 443
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: onlineboutique-credential
```
Test:

```
pratheesh@PF3HLE8F:/home/pratheesh/online-boutique/release$ curl --insecure https://onlineboutique.example.com -s -o /dev/null -v
*   Trying 172.18.255.230:443...
* TCP_NODELAY set
* Connected to onlineboutique.example.com (172.18.255.230) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*   CAfile: /etc/ssl/certs/ca-certificates.crt
  CApath: /etc/ssl/certs
} [5 bytes data]
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
} [512 bytes data]
* TLSv1.3 (IN), TLS handshake, Server hello (2):
{ [122 bytes data]
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
{ [15 bytes data]
* TLSv1.3 (IN), TLS handshake, Certificate (11):
{ [755 bytes data]
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
{ [264 bytes data]
* TLSv1.3 (IN), TLS handshake, Finished (20):
{ [52 bytes data]
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
} [1 bytes data]
* TLSv1.3 (OUT), TLS handshake, Finished (20):
} [52 bytes data]
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
* ALPN, server accepted to use h2
* Server certificate:
*  subject: CN=onlineboutique.example.com; O=demo organization
*  start date: Oct 18 08:11:15 2022 GMT
*  expire date: Oct 18 08:11:15 2023 GMT
*  issuer: O=example Inc.; CN=example.com
*  SSL certificate verify result: unable to get local issuer certificate (20), continuing anyway.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
} [5 bytes data]
* Using Stream ID: 1 (easy handle 0x55b9f9ad62f0)
} [5 bytes data]
> GET / HTTP/2
> Host: onlineboutique.example.com
> user-agent: curl/7.68.0
> accept: */*
> 
{ [5 bytes data]
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
{ [230 bytes data]
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
{ [230 bytes data]
* old SSL session ID is stale, removing
{ [5 bytes data]
* Connection state changed (MAX_CONCURRENT_STREAMS == 2147483647)!
} [5 bytes data]
< HTTP/2 200 
< set-cookie: shop_session-id=15ed8e2e-dfba-4603-9976-333ec0d3bb30; Max-Age=172800
< date: Tue, 18 Oct 2022 08:35:21 GMT
< content-type: text/html; charset=utf-8
< x-envoy-upstream-service-time: 139
< server: istio-envoy
< 
{ [7960 bytes data]
* Connection #0 to host onlineboutique.example.com left intact

```

