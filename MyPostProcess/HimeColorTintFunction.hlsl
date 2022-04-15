//================

struct appdata
{
    float4 vertex:POSITION;
    float2 uv:TEXCOORD0;
};

//================

struct v2f
{
    float4 vertex:SV_POSITION;
    float2 uv:TEXCOORD0;
};

//这里是Dual Kawase，需要增加uv
struct v2f_DualBlurDown
{
    float4 vertex:POSITION;
    float2 uv[5]:TEXCOORD0;
};

struct v2f_DualBlurUp
{
    float2 uv[8]:TEXCOORD0;
    float4 vertex:SV_POSITION;
};

//================

sampler2D _MainTex;
float4 _MainTex_ST;

float4 _ColorTint;
float _BlurRange;
float _RTDownSampling;

float blurrange;
float blurrange_x;
float blurrange_y;

float4 _MainTex_TexelSize;

v2f ColorTintVert (appdata v)
{
    v2f o;
    o.vertex = TransformObjectToHClip(v.vertex);
    o.uv = v.uv;
    return o;
}

//【ColorTint】正片叠底
float4 ColorTintFrag (v2f i):SV_TARGET
{
    float4 col = tex2D(_MainTex, i.uv) * _ColorTint;
    return col;
}

//【高斯模糊的垂直、水平猴版卷积核】，乒乓blit
//严格意义上来说，得逐像素卷积
//也可以写两个frag，一个vertical，一个horizonal，这样9个权重变成3个
float4 GaussianBlurFrag (v2f i):SV_TARGET
{
    float4 col = float4(0, 0, 0, 0);
    blurrange = _BlurRange / 1920;

    col += tex2D(_MainTex, i.uv + float2(0.0, 0.0)) * 0.147716f;
    col += tex2D(_MainTex, i.uv + float2(blurrange, 0.0)) * 0.118318f;
    col += tex2D(_MainTex, i.uv + float2(0.0, -blurrange)) * 0.118318f;
    col += tex2D(_MainTex, i.uv + float2(0.0, blurrange)) * 0.118318f;
    col += tex2D(_MainTex, i.uv + float2(-blurrange, 0.0)) * 0.118318f;

    col += tex2D(_MainTex, i.uv + float2(blurrange, blurrange)) * 0.0947416f;
    col += tex2D(_MainTex, i.uv + float2(-blurrange, -blurrange)) * 0.0947416f;
    col += tex2D(_MainTex, i.uv + float2(blurrange, -blurrange)) * 0.0947416f;
    col += tex2D(_MainTex, i.uv + float2(-blurrange, blurrange)) * 0.0947416f;
    
    return col;
}

//【方波滤波】(Box Blur)
    //此处是3x3的Box
float4 BoxBlurFrag (v2f i):SV_TARGET
{
    float4 col = float4(0, 0, 0, 0);
    blurrange = _BlurRange / 1920;

    col += tex2D(_MainTex, i.uv + float2(0.0, 0.0)) * 0.111111f;

    col += tex2D(_MainTex, i.uv + float2(blurrange, 0.0)) * 0.111111f;
    col += tex2D(_MainTex, i.uv + float2(0.0, -blurrange)) * 0.111111f;
    col += tex2D(_MainTex, i.uv + float2(0.0, blurrange)) * 0.111111f;
    col += tex2D(_MainTex, i.uv + float2(-blurrange, 0.0)) * 0.111111f;

    col += tex2D(_MainTex, i.uv + float2(blurrange, blurrange)) * 0.111111f;
    col += tex2D(_MainTex, i.uv + float2(-blurrange, -blurrange)) * 0.111111f;
    col += tex2D(_MainTex, i.uv + float2(-blurrange, blurrange)) * 0.111111f;
    col += tex2D(_MainTex, i.uv + float2(blurrange, -blurrange)) * 0.111111f;
    
    return col;
}

//【Kawase滤波】(Kawase Blur)
//具体思路是在runtime层，基于当前迭代次数，对每次模糊的半径进行设置，半径越来越大；而Shader层实现一个4 tap的Kawase Filter即可：
    float4 KawaseBlurFrag (v2f i):SV_TARGET
{
    float4 col = tex2D(_MainTex, i.uv);
    blurrange = _BlurRange;

    col += tex2D(_MainTex, i.uv + float2(-1, -1) * blurrange * _MainTex_TexelSize.xy) ;
    col += tex2D(_MainTex, i.uv + float2(1, -1) * blurrange * _MainTex_TexelSize.xy) ;
    col += tex2D(_MainTex, i.uv + float2(-1, 1) * blurrange * _MainTex_TexelSize.xy) ;
    col += tex2D(_MainTex, i.uv + float2(1, 1) * blurrange * _MainTex_TexelSize.xy) ;
    //对目标像素、周围4个对角位置的像素采样，共5个
    
    return col * 0.2;
}

//【双重模糊】(Dual Blur)
// 它相比于Kawasel滤波，有一个降采样 & 升采样的过程，叫做Dual Kawase Blur。降采样和升采样使用不同的pass
    v2f_DualBlurDown DualBlurDownVert (appdata v)
{
    v2f_DualBlurDown o;
    o.vertex = TransformObjectToHClip(v.vertex);

    o.uv[0] = v.uv;
    o.uv[1] = v.uv + float2(-1, -1) * _BlurRange * _MainTex_TexelSize.xy; //↖
	o.uv[2] = v.uv + float2(-1,  1)  * _BlurRange * _MainTex_TexelSize.xy; //↙
	o.uv[3] = v.uv + float2(1,  -1)  * _BlurRange * _MainTex_TexelSize.xy; //↗
	o.uv[4] = v.uv + float2(1,   1)  * _BlurRange * _MainTex_TexelSize.xy; //↘

    return o;
    //5 samples，组成一个五筒
}

float4 DualBlurDownFrag (v2f_DualBlurDown i):SV_TARGET
{
    //降采样
    float4 col = tex2D(_MainTex, i.uv[0]) * 4;

    col += tex2D(_MainTex, i.uv[1]) ;
    col += tex2D(_MainTex, i.uv[2]) ;
    col += tex2D(_MainTex, i.uv[3]) ;
    col += tex2D(_MainTex, i.uv[4]) ;
    
    return col * 0.125; //sum / 8.0f
}

    v2f_DualBlurUp DualBlurUpVert (appdata v)
{
    v2f_DualBlurUp o;
    o.vertex = TransformObjectToHClip(v.vertex);

	o.uv[0] = v.uv + float2(-1,-1) * _BlurRange * _MainTex_TexelSize.xy;
	o.uv[1] = v.uv + float2(-1, 1) * _BlurRange * _MainTex_TexelSize.xy;
	o.uv[2] = v.uv + float2(1, -1) * _BlurRange * _MainTex_TexelSize.xy;
	o.uv[3] = v.uv + float2(1,  1) * _BlurRange * _MainTex_TexelSize.xy;
	o.uv[4] = v.uv + float2(-2, 0) * _BlurRange * _MainTex_TexelSize.xy;
	o.uv[5] = v.uv + float2(0, -2) * _BlurRange * _MainTex_TexelSize.xy;
	o.uv[6] = v.uv + float2(2,  0) * _BlurRange * _MainTex_TexelSize.xy;
	o.uv[7] = v.uv + float2(0,  2) * _BlurRange * _MainTex_TexelSize.xy;
    return o;
}

float4 DualBlurUpFrag (v2f_DualBlurUp i):SV_TARGET
{
    //升采样
    float4 col = 0;

    col += tex2D(_MainTex, i.uv[0] * 2) ;
    col += tex2D(_MainTex, i.uv[1] * 2) ;
    col += tex2D(_MainTex, i.uv[2] * 2) ;
    col += tex2D(_MainTex, i.uv[3] * 2) ;
    col += tex2D(_MainTex, i.uv[4]) ;
    col += tex2D(_MainTex, i.uv[5]) ;
    col += tex2D(_MainTex, i.uv[6]) ;
    col += tex2D(_MainTex, i.uv[7]) ;

    return col * 0.0833; //sum / 12.0f
}

//Dual Blur End

