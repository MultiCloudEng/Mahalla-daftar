const C="daftar-v8";
const CORE=["./","index.html","config.js","manifest.json","icon-192.png","icon-512.png"];
const LIB="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js";
self.addEventListener("install",e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(CORE).then(()=>c.add(LIB).catch(()=>{}))).then(()=>self.skipWaiting()))});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});

// Network first for app files so updates arrive, but give up after 3.5 s on a slow
// connection and use the saved copy (the network answer still refreshes the cache).
function networkFirst(req){
  const net=fetch(req).then(r=>{if(r&&r.ok){const cp=r.clone();caches.open(C).then(c=>c.put(req,cp))}return r});
  return caches.match(req).then(cached=>{
    if(!cached)return net.catch(()=>caches.match("index.html"));
    const timer=new Promise(res=>setTimeout(()=>res(cached),3500));
    return Promise.race([net.catch(()=>cached),timer]);
  });
}
self.addEventListener("fetch",e=>{
  if(e.request.method!=="GET")return;
  const u=new URL(e.request.url);
  if(u.origin===location.origin){
    e.respondWith(networkFirst(e.request));
  }else if(/(^|\.)fonts\.(googleapis|gstatic)\.com$/.test(u.hostname)||u.hostname==="cdn.jsdelivr.net"){
    // fonts and the pinned Supabase library: cache first
    e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request).then(res=>{const cp=res.clone();caches.open(C).then(c=>c.put(e.request,cp));return res})));
  }
  // Supabase API calls are never cached: they always go to the network
});
