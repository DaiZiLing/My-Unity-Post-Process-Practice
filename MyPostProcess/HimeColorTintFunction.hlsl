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
    o.vertex = TransformObjectToHClip(v.vertex.xyz);
    o.uv = v.uv;
    return o;
}

//【ColorTint】正片叠底
float4 ColorTintFrag (v2f i):SV_TARGET
{
    float4 col = tex2D(_MainTex, i.uv) * _ColorTint;
    return col;
}

//【高斯模糊的垂直、水平猴版卷积核】
//严格意义上来说，得逐像素卷积
//也可以写两个frag，带来两个pass，一个vertical，一个horizonal。线性近似里，这样9个权重变成3个
//越大的filter，越费
//5x5的带宽和kawase差不多，但dual在这个基础上还能省50%

#define SMALL_KERNEL 7
#define MEDIUM_KERNEL 35
#define BIG_KERNEL 127 //实时渲染别想用这玩意儿

//高斯函数
float Guass(float x, float y, float sigma)
{
    float Gauss_Value;
    Gauss_Value = 1.0f / (2.0f * PI * sigma * sigma) * exp(-(x * x + y * y) / (2.0f * sigma * sigma));
    return Gauss_Value;
}

//【三维豪华版高斯】
float4 GaussianBlurFullFrag (v2f i):SV_TARGET
{
    float4 col = float4(0, 0, 0, 0);
    float2 UV_Offset;
    float Gaussian_Weight;
    float Gauss_Sum = 0;

    int Kernel_Size = SMALL_KERNEL;
    for (int x = -Kernel_Size / 2; x <= Kernel_Size / 2; x++)
    {
        for (int y = -Kernel_Size / 2; y <= Kernel_Size / 2; y++)
        {
            UV_Offset = i.uv;
            UV_Offset.x += x * _MainTex_TexelSize.x;
            UV_Offset.y += y * _MainTex_TexelSize.y;

            Gaussian_Weight = Guass(x, y, _BlurRange + 0.01);//_BlurRange就是sigma，是高斯函数的胖瘦程度，加个0.01防止为0
            col += tex2D(_MainTex, UV_Offset) * Gaussian_Weight;
            Gauss_Sum += Gaussian_Weight;
        }
    }
    col *= (1.0f / Gauss_Sum);
    return col;
}

//【猴版，线性近似的高斯】
float4 GaussianBlurFrag (v2f i):SV_TARGET
{
    float4 col = float4(0, 0, 0, 0);
    blurrange = _BlurRange / 300;

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

//【豪华版Box】
float4 BoxBlurFullFrag (v2f i):SV_TARGET
{
    float4 col = float4(0, 0, 0, 0);
    float2 UV_Offset;

    float Box_Weight = 0.11111;

    for (int x = -1; x <= 1; x++)
    {
        for (int y = -1; y <= 1; y++)
        {
            UV_Offset = i.uv;
            UV_Offset.x += x * _MainTex_TexelSize.x * _BlurRange / 3;
            UV_Offset.y += y * _MainTex_TexelSize.y * _BlurRange / 3;
            col += tex2D(_MainTex, UV_Offset);
        }
    }
    col *= 0.11111;
    return col;
}

//【猴版方波滤波】(Box Blur)
    //此处是3x3的Box，好像和豪华版也差不了多少
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
    //降采样
    v2f_DualBlurDown o;
    o.vertex = TransformObjectToHClip(v.vertex.xyz);
    o.uv[0] = v.uv;

#if UNITY_UV_STARTS_TOP
    o.uv[0].y = 1 - o.uv[0].y;
#endif
	//
    o.uv[1] = v.uv + float2(-1, -1)  * (1 + _BlurRange) * _MainTex_TexelSize.xy * 0.5; //↖
	o.uv[2] = v.uv + float2(-1,  1)  * (1 + _BlurRange) * _MainTex_TexelSize.xy * 0.5; //↙
	o.uv[3] = v.uv + float2(1,  -1)  * (1 + _BlurRange) * _MainTex_TexelSize.xy * 0.5; //↗
	o.uv[4] = v.uv + float2(1,   1)  * (1 + _BlurRange) * _MainTex_TexelSize.xy * 0.5; //↘
	//
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
    //升采样
    v2f_DualBlurUp o;
    o.vertex = TransformObjectToHClip(v.vertex.xyz);
    o.uv[0] = v.uv;

#if UNITY_UV_STARTS_TOP
    o.uv[0].y = 1 - o.uv[0].y;
#endif
	//
	o.uv[0] = v.uv + float2(-1,-1) * (1 + _BlurRange) * _MainTex_TexelSize.xy * 0.5;
	o.uv[1] = v.uv + float2(-1, 1) * (1 + _BlurRange) * _MainTex_TexelSize.xy * 0.5;
	o.uv[2] = v.uv + float2(1, -1) * (1 + _BlurRange) * _MainTex_TexelSize.xy * 0.5;
	o.uv[3] = v.uv + float2(1,  1) * (1 + _BlurRange) * _MainTex_TexelSize.xy * 0.5;
	o.uv[4] = v.uv + float2(-2, 0) * (1 + _BlurRange) * _MainTex_TexelSize.xy * 0.5;
	o.uv[5] = v.uv + float2(0, -2) * (1 + _BlurRange) * _MainTex_TexelSize.xy * 0.5;
	o.uv[6] = v.uv + float2(2,  0) * (1 + _BlurRange) * _MainTex_TexelSize.xy * 0.5;
	o.uv[7] = v.uv + float2(0,  2) * (1 + _BlurRange) * _MainTex_TexelSize.xy * 0.5;
    //
    return o;
}

float4 DualBlurUpFrag (v2f_DualBlurUp i):SV_TARGET
{
    //升采样
    float4 col = 0;

    col += tex2D(_MainTex, i.uv[0]) * 2;
    col += tex2D(_MainTex, i.uv[1]) * 2;
    col += tex2D(_MainTex, i.uv[2]) * 2;
    col += tex2D(_MainTex, i.uv[3]) * 2;
    col += tex2D(_MainTex, i.uv[4]) ;
    col += tex2D(_MainTex, i.uv[5]) ;
    col += tex2D(_MainTex, i.uv[6]) ;
    col += tex2D(_MainTex, i.uv[7]) ;

    return col * 0.0833; //sum / 12.0f
}

//Dual Blur End

