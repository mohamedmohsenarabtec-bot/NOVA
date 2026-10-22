// Every image response checks live Auth + metadata RLS. No signed URLs,
// transferable storage access, private keys or request headers are logged.
const origins = new Set(["https://mohamedmohsenarabtec-bot.github.io", "http://localhost:3000", "http://127.0.0.1:3000"]);
Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");
  const headers = new Headers({"Cache-Control":"private, no-store, max-age=0","Vary":"Origin","X-Content-Type-Options":"nosniff","Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info","Access-Control-Allow-Methods":"POST, OPTIONS"});
  if (origin && !origins.has(origin)) return new Response(null,{status:403});
  if (origin) headers.set("Access-Control-Allow-Origin",origin);
  const fail = (status:number) => {const h=new Headers(headers);h.set("Content-Type","application/json");return new Response(JSON.stringify({error:"Photo unavailable"}),{status,headers:h});};
  if(request.method==="OPTIONS") return new Response(null,{status:204,headers});
  if(request.method!=="POST") return fail(405);
  const authorization=request.headers.get("authorization");
  if(!authorization?.startsWith("Bearer ")) return fail(401);
  try {
    const url=Deno.env.get("SUPABASE_URL")!;
    const publicKey=Deno.env.get("SUPABASE_ANON_KEY")!;
    const serverKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const userHeaders={apikey:publicKey,Authorization:authorization};
    const user=await fetch(`${url}/auth/v1/user`,{headers:userHeaders});
    if(!user.ok || !(await user.json()).id) return fail(401);
    if(Number(request.headers.get("content-length")??0)>512) return fail(400);
    const {photo_id:id}=await request.json();
    if(typeof id!=="string"||!/^[a-f0-9-]{36}$/.test(id)) return fail(400);
    const query=await fetch(`${url}/rest/v1/profile_photos?id=eq.${id}&ready=eq.true&select=path&limit=1`,{headers:{...userHeaders,"Cache-Control":"no-cache"}});
    if(!query.ok) return fail(404);
    const rows=await query.json();
    if(!Array.isArray(rows)||rows.length!==1) return fail(404);
    const path=rows[0].path.split("/").map(encodeURIComponent).join("/");
    const stored=await fetch(`${url}/storage/v1/object/authenticated/private-media/${path}`,{headers:{apikey:serverKey,Authorization:`Bearer ${serverKey}`}});
    if(!stored.ok) return fail(404);
    headers.set("Content-Type","application/octet-stream");
    return new Response(stored.body,{status:200,headers});
  }catch(_){return fail(400);}
});
