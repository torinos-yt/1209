//@author: vux
//@help: basic pixel based lightning with directional light
//@tags: shading, blinn
//@credits: vvvv group

#define SC 15000

float2x2 m2 = float2x2(0.8,-0.6,0.6,0.8);
float3 light1 = normalize( float3(-0.8,0.4,-0.3) );

struct vsInputTextured
{
    float4 posObject : POSITION;
	float4 normalObject : NORMAL;
	float4 uv: TEXCOORD0;
	float3 tangent : TANGENT;
};

struct psInputTextured
{
    float4 posScreen : SV_Position;
    float4 uv: TEXCOORD0;
    float3 LightDirV: TEXCOORD1;
    float3 NormV: TEXCOORD2;
    float3 ViewDirV: TEXCOORD3;
	float3 tangent : TEXCOORD4;
	float4 pos : POSITION;
};

Texture2D inputTexture <string uiname="Texture";>;
Texture2D BumpTex;
Texture2D NoiseTex;
float bumps;

SamplerState linearSampler <string uiname="Sampler State";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
}; 

cbuffer cbPerDraw : register(b0)
{
	float4x4 tLAV: LAYERVIEW;
	float4x4 tV : VIEW;
	float4x4 tP: PROJECTION;
	float4x4 tLVP: LAYERVIEWPROJECTION;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
	float4x4 tWV: WORLDLAYERVIEW;
	float4x4 tWIT: WORLDINVERSETRANSPOSE;
	
	float Alpha <float uimin=0.0; float uimax=1.0;> = 1; 
	float4 cAmb <bool color=true;String uiname="Color";> = { 1.0f,1.0f,1.0f,1.0f };
	float4x4 tColor <string uiname="Color Transform";>;
};

cbuffer cbTextureData : register(b2)
{
	float4x4 tTex <string uiname="Texture Transform"; bool uvspace=true; >;
};

float fbm( float2 p )
{
    float f = 0.0;
    f += 0.5000*NoiseTex.Sample( linearSampler, p/256.0 ).x; p = mul(p*2.02, m2);
    f += 0.2500*NoiseTex.Sample( linearSampler, p/256.0 ).x; p = mul(p*2.03, m2);
    f += 0.1250*NoiseTex.Sample( linearSampler, p/256.0 ).x; p = mul(p*2.01, m2);
    f += 0.0625*NoiseTex.Sample( linearSampler, p/256.0 ).x;
    return f/0.9375;
}

#include "PhongDirectional.fxh"

psInputTextured VS_Textured(float4 PosO: POSITION,float3 NormO: NORMAL, float4 TexCd : TEXCOORD0, float3 tangent : TANGENT)
{
    psInputTextured output;
  
    //inverse light direction in view space
    output.LightDirV = normalize(-mul(float4(lDir,0.0f), tV).xyz);
    
    //normal in view space
    output.NormV = normalize(mul(NormO, (float3x3)tWIT));

    //position (projected)
	output.pos = mul(PosO, tW);
    output.posScreen  = mul(PosO, mul(tW, tLVP));
    output.uv = mul(TexCd, tTex);
    output.ViewDirV = -normalize(mul(PosO, tWV).xyz);
	output.tangent = normalize(mul(tangent, (float3x3)tWIT));
    return output;
}
float4 PS_Textured(psInputTextured input): SV_Target
{	
	float3 rd = normalize(float3(input.posScreen.xy, 1));
	float3 hal = normalize(light1-rd);
	float3 bnormal = normalize(cross(input.NormV, input.tangent));
	float3 nmap = BumpTex.Sample(linearSampler, input.uv.xy).xyz;
	nmap = nmap * 2.0 - 1.0;
	float3 nor = float4(normalize(input.NormV + (nmap.x * input.tangent + nmap.y * bnormal) * bumps), 1);
    
	float3 col;
	
	// rock
	float r = NoiseTex.Sample(linearSampler, (7.0/SC)*input.pos.xz/256.0 ).x;
    col = (r*0.25+0.75)*0.9*lerp( float3(0.08,0.05,0.03), float3(0.10,0.09,0.08), 
                                     NoiseTex.Sample(linearSampler, 0.00007*float2(input.pos.x,input.pos.y*48.0)/SC).x );
	col = lerp( col, 0.20*float3(0.45,.30,0.25)*(0.50+0.50*r),smoothstep(0.70,0.9,nor.y) );
    col = lerp( col, 0.15*float3(0.30,.30,0.2)*(0.25+0.75*r),smoothstep(0.95,1.0,nor.y) );

	// snow
	float h = smoothstep(55.0,80.0,input.pos.y/SC + 25.0*fbm(0.01*input.pos.xz/SC) );
    float e = smoothstep(1.0-0.5*h,1.0-0.1*h,nor.y);
    float o = 0.3 + 0.7*smoothstep(0.0,0.1,nor.x+h*h);
    float s = h*e*o;
    col = lerp( col, 0.35*float3(0.62,0.65,0.8), smoothstep(0, 1,dot(nor, float3(0,1,0))*1.2) * fbm(input.pos.xy));
			
	  // lighting		
    float amb = clamp(0.5+0.5*nor.y,0.0,1.0);
	float dif = clamp( dot( light1, nor ), 0.0, 1.0 )+.1;
	float bac = clamp( 0.2 + 0.8*dot( normalize( float3(-light1.x, 0.0, light1.z ) ), nor ), 0.0, 1.0 );
		
	float3 lin  = 0;
	lin += dif*float3(7.00,5.00,3.00)*1.3;
	lin += amb*float3(0.40,0.60,1.00)*1.2;
    lin += bac*float3(0.40,0.50,0.60);
	col *= lin;
        
    //col += s*0.1*pow(fre,4.0)*vec3(7.0,5.0,3.0)*sh * pow( clamp(dot(nor,hal), 0.0, 1.0),16.0);
    /*col += s*
           (0.04+0.96*pow(clamp(1.0+dot(hal,rd),0.0,1.0),5.0))*
    float3(7.0,5.0,3.0)*dif*
    pow( clamp(dot(nor,hal), 0.0, 1.0),16.0);
        
       */
    //col += s*0.1*pow(fre,4.0)*float3(0.4,0.5,0.6)*smoothstep(0.0,0.6,ref.y);

	
	
    col += PhongDirectional(normalize(mul(nor, tLAV).xyz), input.ViewDirV, input.LightDirV).xyz*.1;
    return mul(float4(col, Alpha), tColor);
}

technique10 GouraudDirectional <string noTexCdFallback="GouraudDirectionalNotexture"; >
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS_Textured() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_Textured() ) );
	}
}
