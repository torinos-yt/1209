#ifndef ITERATION
#define ITERATION 30
#endif

struct vsInputTextured
{
    float4 posObject : POSITION;
	float4 normalObject : NORMAL;
	float4 uv: TEXCOORD0;
};

struct psInputTextured
{
    float4 posScreen : SV_Position;
	float4 posW : TEXCOORD2;
    float4 uv: TEXCOORD0;
	float4 posSc : TEXCOORD1;
	float3 NormW : NORMAL;
};

struct psout
{
    float4 color : SV_Target;
	float depth : SV_Depth;
};

float rad;

float time;
float rotspeed;
float scale;

float4x4 distRot;

float maxd<string uiname = "Max Distance";> = 500;
float mind<string uiname = "Min Distance";> = .01;

float stepLength = 1;

float uvScale = 2;

Texture2D tex <string uiname="Texture";>;
float4x4 texW;

SamplerState linearSampler <string uiname="Sampler State";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

cbuffer cbPerDraw : register(b0)
{
	float4x4 tV: VIEW;
	float4x4 tP: PROJECTION;
	float4x4 tVP: VIEWPROJECTION;
	float4x4 tVI : VIEWINVERSE;
	float4x4 tPI : PROJECTIONINVERSE;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
	float4x4 tWV: WORLDVIEW;
	float4x4 tWI: WORLDINVERSE;
	
};

cbuffer cbTextureData : register(b2)
{
	float4x4 tTex <string uiname="Texture Transform"; bool uvspace=true; >;
};

float2x2 rot2D(float a) {
	float c = cos(a);
	float s = sin(a);
	return float2x2(c, s,
					-s, c);
}

float3 mod(float3 n, float d){
	return n - (d * floor(n / d));
}

float3 dRep(float3 p, float c) {
    return mod(p, c) - 0.5 * c;
}

float dSphere(float3 p, float s){
  return length(p)-s;
}

float dBox(float3 p, float3 pos, float3 size){
	float3 d = abs(p - pos) - size;
	return length(max(d,0.0))
         + min(max(d.x,max(d.y,d.z)),0.0);
}

float dMundelbulb(float3 rayPos, float3 size){
	float3 p = mod(rayPos, 2.0)-2.0*.5;
	//float3 p = rayPos;
	
	float mr = .1, mxr = 2;
	float4 scale = size.x, p0 = float4(0.3, 0.9, -1.4, 0.5);
	float4 z = float4(p, 1);
	for(int n = 0; n < 8; n++){
		z.xyz = clamp(z.xyz, -1.25, 1.5) * 2.1 - z.xyz;
		z *= scale / clamp(dot(z.xyz, z.xyz), mr, mxr) * 2;
		z += p0;
	}
	
	float ds = (length(max(abs(z.xyz), 0.0))) / z.w;
	return ds;
}

float dMenger(float3 rayPos, float3 offset, float3 scale) {
	scale.xyz = scale.x;
    float4 z = float4(rayPos, 1.0);
    for (int i = 0; i < 5; i++) {
        z = abs(z);
        if (z.x < z.y) z.xy = z.yx;
        if (z.x < z.z) z.xz = z.zx;
        if (z.y < z.z) z.yz = z.zy;
        
        z *= scale.x;
        z.xyz -= offset * (scale - 1.0);
        
        if (z.z < -0.3 * offset.z * (scale.x - 1.0)) {
            z.z += offset.z * (scale.x - 1.0);
        }
    }
    return length(max(abs(z.xyz) - float3(1,1,1), 0.0)) / z.w;
}


float dMengerRep(float3 p) {
	p -= float3(.75,.5,-time);
	p = dRep(p, 1.1);
	//p.xy = mul(p.xy, rot2D(3.0 * time * rotspeed * p.z));
	float t = 1.0 + sin(time);
	t *= 5.0;
	float d = dMenger(p, 1.1, scale);
	return d;
}

float dScene(float3 p){
	return  min(dMengerRep(mul(float4(p*.66, 1), transpose(distRot)).xyz), dMengerRep(mul(float4(p*.9, 1), distRot).xyz));
}

bool IsInnerSphere(float3 pos, float3 scale)
{
    return length(pos) < abs(scale) * 0.5;
}

float3 getNormal(float3 pos){
	float ep = .001;
	return normalize(float3(
		dScene(pos) - dScene(float3(pos.x-ep, pos.y, pos.z)),
		dScene(pos) - dScene(float3(pos.x, pos.y-ep, pos.z)),
		dScene(pos) - dScene(float3(pos.x, pos.y, pos.z-ep))));
}


psInputTextured VS_Textured(vsInputTextured input)
{
    psInputTextured output;

    //inverse light direction in view space


	output.NormW = mul(input.normalObject, tW).xyz;
    //view direction = inverse vertexposition in viewspace
    float4 PosV = mul(input.posObject, tWV);
	output.posW = mul(input.posObject, tW);

    //position (projected)
    output.posScreen  = mul(PosV, tP);
	output.posSc = output.posScreen;
    output.uv = mul(input.uv, tTex);
    return output;
}

psout PS_Textured(psInputTextured input)
{
	psout output;
	float2 sdir = input.posSc.xy / input.posSc.w;
	float3 rayDir = normalize(mul(float4(mul(float4((sdir),0,1), tPI).xy,1,0), tVI).xyz);
	float3 rayPos = input.posW.xyz;
	float total = 0;
	float4 color = float4(0,0,0,0);
	float3 norm = input.NormW*.5+.5;
	
	//rayPos += rayDir * mind;
	
	for(int i = 0; i < ITERATION; i++){
		float d = dScene(mul(float4(rayPos, 1), tWI).xyz);
		if(!IsInnerSphere(mul(float4(rayPos, 1), tWI).xyz, rad*2)) discard;
		if(d < .001){
			
			float u = (rayPos.x+rayPos.z)*uvScale;
			float v = (rayPos.y+rayPos.z)*uvScale;
			color = float4(.5,.5,.65,1);
			color += tex.SampleLevel(linearSampler, mul(float2(u, v), (float2x2)tTex), 0);
			//color = min(color, mamb);
			
			break;
		}
		if(total > maxd) break;
		rayPos += rayDir * d * stepLength;
		total += d;
	}
	
	float glow = 0.0;
    
    float s = 0.0075;
    float3 p = mul(float4(rayPos,1), tWI).xyz;
	float3 n1 = norm;
    float3 n2 = norm;
    float3 n3 = norm;
    glow = max(1.0-abs(dot(p, n1)-.8), 0.0)*0.5;  
	 
	
	output.color = color+glow;
	float4 posw = mul(float4(rayPos, 1), tVP);
	output.depth = posw.z / posw.w;
	
	return output;
}

technique11 GouraudDirectional <string noTexCdFallback="GouraudDirectionalNotexture"; >
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS_Textured() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_Textured() ) );
	}
}
