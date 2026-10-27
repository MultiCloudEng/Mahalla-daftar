const C="daftar-v10";
const CORE=["./","index.html","config.js","manifest.json","icon-192.png","icon-512.png","vendor/supabase-2.45.4.js"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(CORE)).then(()=>self.skipWaiting()))});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x.startsWith("daftar-")&&x!==C).map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});

// Network first for app files so updates arrive, but give up after 3.5 s on a slow
// connection and use the saved copy (the network answer still refreshes the cache).
function networkFirst(req){
  const net=fetch(req).then(r=>{if(!r||!r.ok)throw new Error("bad "+(r&&r.status));const cp=r.clone();caches.open(C).then(c=>c.put(req,cp));return r});
  return caches.match(req).then(cached=>{
    if(!cached)return net.catch(()=>req.mode==="navigate"?caches.match("index.html").then(r=>r||fetch(req)):fetch(req));
    const timer=new Promise(res=>setTimeout(()=>res(cached),3500));
    return Promise.race([net.catch(()=>cached),timer]);
  });
}
self.addEventListener("fetch",e=>{
  if(e.request.method!=="GET")return;
  const u=new URL(e.request.url);
  if(u.origin===location.origin){
    e.respondWith(networkFirst(e.request));
  }else if(/(^|\.)fonts\.(googleapis|gstatic)\.com$/.test(u.hostname)){
    // fonts: cache first, only good responses are kept
    e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request).then(res=>{if(res.ok||res.type==="opaque"){const cp=res.clone();caches.open(C).then(c=>c.put(e.request,cp))}return res})));
  }
  // Supabase API calls are never cached: they always go to the network
});
