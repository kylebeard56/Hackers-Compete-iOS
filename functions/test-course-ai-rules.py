import subprocess, urllib.request, urllib.error, json, ssl
from pathlib import Path
project='hackers-compete-sandbox'
token=subprocess.check_output(['gcloud','auth','print-access-token'],text=True).strip()
source={'files':[{'name':'firestore.rules','content':Path('firestore.rules').read_text()}]}
cases=[]
for auth in [None, {'uid':'test-user','token':{}}]:
    for collection, expected in [('courseAIUsage','DENY'),('courses','ALLOW'),('rounds','ALLOW')]:
        for method in ['get','list','create','update','delete']:
            cases.append({'expectation':expected,'request':{'auth':auth,'path':'/databases/(default)/documents/'+collection+'/test-document','method':method,'time':'2026-09-14T18:00:00Z','resource':{'data':{}}},'resource':{'data':{}}})
body={'source':source,'testSuite':{'testCases':cases}}
req=urllib.request.Request('https://firebaserules.googleapis.com/v1/projects/'+project+':test',data=json.dumps(body).encode(),headers={'Authorization':'Bearer '+token,'x-goog-user-project':project,'Content-Type':'application/json'})
try:
    with urllib.request.urlopen(req,timeout=45,context=ssl.create_default_context(cafile='/etc/ssl/cert.pem')) as res: result=json.load(res)
    Path('/tmp/hackers-ai-rules-test-results.json').write_text(json.dumps(result,indent=2))
    print('Compile issues:',result.get('issues',[]))
    states=[test.get('state') for test in result.get('testResults',[])]
    print('Rule checks:',len(states),'states:',{state:states.count(state) for state in set(states)})
    if any(state!='SUCCESS' for state in states) or len(states)!=len(cases): raise SystemExit(1)
except urllib.error.HTTPError as error:
    print(error.code,error.read().decode());raise SystemExit(1)
