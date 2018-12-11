//@author: vux
//@help: template for standard shaders
//@tags: template
//@credits: 

#ifndef ITERATION
#define ITERATION 30
#endif

Texture2D tex <string uiname="Texture";>;
float time;
float rotspeed;

float4x4 cubeRot;

SamplerState linearSampler : IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};
 
cbuffer cbPerDraw : register( b0 )
{
	float4x4 tVP : LAYERVIEWPROJECTION;	
	float4x4 tVI : VIEWINVERSE;
	float4x4 tPI : PROJECTIONINVERSE;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
	float4x4 tWI : WORLDINVERSE;
	float4 cAmb <bool color=true;String uiname="Color";> = { 1.0f,1.0f,1.0f,1.0f };
	float3 size = 1;
};

float3 LightDir = normalize(float3(1.0,1.0,1.0));

float maxd<string uiname = "Max Distance";> = 500;
float mind<string uiname = "Min Distance";> = .01;

float stepLength = 1;

float uvScale = 2;

struct VS_IN
{
	float4 PosO : POSITION;
	float4 TexCd : TEXCOORD0;

};

struct psinput
{
	float4 PosWVP : SV_Position;
	float2 uv : TEXCOORD0;
};

struct psout{
	float4 col : SV_Target;
	float depth : SV_Depth;
};

/* //sphere
float distfunc(float3 pos, float size){
	return length(pos) - size;
}
*/

/* //box
float distfunc(float3 rayPos, float3 size){
	rayPos = fmod(rayPos, 15) - 15 *.5;
	return length(max(abs(rayPos) - size, 0.0))-.1;
}
*/

/* //torus
float distfunc(float3 rayPos, float3 size){
	float2 q = float2(length(rayPos.xz) - size.x, rayPos.y);
	return length(q) - size.y;
}
*/

/* //fractal
float distfunc(float3 rayPos, float3 size){
	float3 p = rayPos = fmod(rayPos, 2) - 2*.5;
	
	float3 a1 = float3(1,1,1);
	float3 a2 = float3(-1,-1,1);
	float3 a3 = float3(1,-1,-1);
	float3 a4 = float3(-1,1,-1);
	
	float d;
	for(int n = 0; n < 20; n++){
		float3 c = a1;
		float minD = length(p - a1);
		d = length(p - a2); 
		if(d < minD) {
			c = a2; minD = d;
		}
		d = length(p - a3); 
		if(d < minD) {
			c = a3; minD = d;
		}
		d = length(p - a4); 
		if(d < minD) {
			c = a4; minD = d;
		}
		p = size * p - c * (size - 1.0);
	}
	
	return length(p) * pow(abs(size.x), float(-n));
}
*/


/*float distfunc(float3 rayPos, float3 size){
	float3 p = fmod(rayPos, 2.0)-2.0*.5;
	//float3 p = rayPos;
	
	float mr = .25, mxr = 1.0;
	float4 scale = size.x, p0 = float4(0, 0.59, -1.0, 0.0);
	float4 z = float4(p, 1);
	for(int n = 0; n < 8; n++){
		z.xyz = clamp(z.xyz, -0.94, 0.94) * 2 - z.xyz;
		z *= scale / clamp(dot(z.xyz, z.xyz), mr, mxr) * .97;
		z += p0;
	}
	
	float ds = (length(max(abs(z.xyz), 0.0))) / z.w;
	return ds;
}*/

float3 mod(float3 n, float d){
	return n - (d * floor(n / d));
}

float3 dRep(float3 p, float3 c) {
    return mod(p, c) - 0.5 * c;
}

float2x2 rot2D(float a) {
	float c = cos(a);
	float s = sin(a);
	return float2x2(c, s,
					-s, c);
}

float dBox(float3 rayPos, float3 pos, float3 size){
	float3 d = abs(rayPos - pos) - size;
	return length(max(d,0.0))
         + min(max(d.x,max(d.y,d.z)),0.0);
}

//@gam0022
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
        
        if (z.z < -0.5 * offset.z * (scale.x - 1.0)) {
            z.z += offset.z * (scale.x - 1.0);
        }
    }
    return length(max(abs(z.xyz) - float3(1,1,1), 0.0)) / z.w;
}


float dMengerRep(float3 p) {
	p -= float3(.75,.75,-time);
	p = dRep(p, float3(1.5, 1.5, 1.5));
	p.xy = mul(p.xy, rot2D(3.0 * cos(time * rotspeed) * p.z));
	float t = 1.0 + sin(time);
	t *= 3.0;
	float d = dMenger(p, float3(0.62, 0.85, abs(sin(time))), 2.56);
	return d;
}

float dMBox(float3 p) {
	float bs = 0.1;
	float op = .11;
	p = mul(p, cubeRot);
	//p +=  float3(0,0,time)/2;
	//p = dRep(p, 30);
	p = abs(p * 5);
	return max(max(max(dBox(p, op.xxx, bs.xxx), -dBox(p, op.xxx, float3(.05, .05, 5))), -dBox(p, op.xxx, float3(.05, .5, .05))), -dBox(p, op.xxx, float3(5, .05, .05)));
}

float dScene(float3 p){
	return min(dMengerRep(p), dMBox(p));
}

float dIsMenger(float3 p){
	return dMengerRep(p) < dMBox(p);
}



/*
static const float minRadius2 = 0.5;
static const float fixedRadius2 = 1.0;
static const float foldingLimit = 1.0;

void spherefold(inout float3 z, inout float dz) {
	float r2 = dot(z,z);
	if (r2 < minRadius2) {
		// linear inner scaling
		float temp = (fixedRadius2 / minRadius2);
		z *= temp;
		dz *= temp;
	} else if (r2 < fixedRadius2) {
		// this is the actual sphere inversion
		float temp = fixedRadius2 / r2;
		z *= temp;
		dz *= temp;
	}
}
void boxfold(inout float3 z, inout float dz) {
	z = clamp(z, -foldingLimit, foldingLimit) * 2.0 - z;
}
float mb(float3 rayPos, float3 scale) {
	float3 offset = rayPos;
	float dr = 1.0;
	for (int n = 0; n < 7; n++) {
		boxfold(rayPos, dr);       // Reflect
		spherefold(rayPos, dr);    // Sphere Inversion
		rayPos = scale.x * rayPos + offset;  // Scale & Translate
		dr = dr * abs(scale.x) + 1.0;
	}
	float r = length(rayPos);
	return r / abs(dr);
}

static const float3 scale2 = -1.9;

float distfunc(float3 rayPos, float3 scale){
	float p = mb(rayPos, scale);
	//float p1 = mb(rayPos, scale2);
	return p;
}
*/

float3 getNormal(float3 pos, float3 size){
	float ep = .001;
	float3 offset = 0;
	return normalize(float3(
		dScene(pos) - dScene(float3(pos.x-ep, pos.y, pos.z)),
		dScene(pos) - dScene(float3(pos.x, pos.y-ep, pos.z)),
		dScene(pos) - dScene(float3(pos.x, pos.y, pos.z-ep))));
}

psinput VS(VS_IN input)
{
    psinput output;
    output.PosWVP  = input.PosO;
    output.uv = input.TexCd.xy;
    return output;
}

psout PS(psinput input)
{
	
	psout output;
	float mamb = .35;
	float4 color = mamb;
	
	float3 rayDir = normalize(mul(float4(mul(float4((input.uv*2.0-1.0)*float2(1,-1),0,1), tPI).xy,1,0), tVI).xyz);
	float3 rayPos = tVI[3].xyz;
	float total = 0;
	
	rayPos += rayDir * mind;
	float3 off = 0;
	
	for(int i = 0; i < ITERATION; i++){
		float d = dScene(mul(float4(rayPos,1), tWI).xyz);
		if(d < 0.001){
			float3 normal = normalize(mul(float4(getNormal(mul(float4(rayPos,1), tWI).xyz, size),0), tW).xyz);
			float u = rayPos.x*uvScale;
			float v = rayPos.y*uvScale;
			float2 uv = float2(u, v);
			uv = mul(uv, rot2D(5.0 * cos(time)));
			float4 texel = tex.SampleLevel(linearSampler, uv,0);
			color = float4((texel.rgb * dot(LightDir, normal) * cAmb.rgb )+.45, 1);
			color += float4(normal*.09, 0);
			color = min(color, mamb);
			
			break;
		}
		if(total > maxd) break;
		rayPos += rayDir*d * stepLength;
		total += d;
	}
	
	output.col = color;
	float4 posw = mul(float4(rayPos, 1), tVP);
	output.depth = posw.z / posw.w;
	
	return output;
}

psout PS_Constant(psinput input)
{
	
	psout output;
	float mamb = .25;
	float4 color = mamb;
	
	float3 rayDir = normalize(mul(float4(mul(float4((input.uv*2.0-1.0)*float2(1,-1),0,1), tPI).xy,1,0), tVI).xyz);
	float3 rayPos = tVI[3].xyz;
	float total = 0;
	
	rayPos += rayDir * mind;
	float3 off = 0;
	for(int i = 0; i < ITERATION; i++){
		float d = dScene(mul(float4(rayPos,1), tWI).xyz);
		if(d < 0.001){
			//float3 normal = normalize(mul(float4(getNormal(mul(float4(rayPos,1), tWI).xyz, size),0), tW).xyz);
			float u = (rayPos.x+rayPos.z)*uvScale;
			float v = (rayPos.y+rayPos.z)*uvScale;
			if(dIsMenger(mul(float4(rayPos,1), tWI).xyz)){
				float4 texel = tex.SampleLevel(linearSampler, float2(u,v),0);
				color = texel;
			//color = float4(normal, 1.0);
			}else{
				color = float4(.6,.7,.85,1);
			}
			//color = min(color, mamb);
			
			break;
		}
		if(total > maxd) break;
		rayPos += rayDir*d * stepLength;
		total += d;
	}
	
	output.col = color;
	float4 posw = mul(float4(rayPos, 1), tVP);
	output.depth = posw.z / posw.w;
	
	return output;
}





technique10 Constant
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_Constant() ) );
	}
}

technique10 Lambert
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}




