struct appdata
{
    float4 vertex:POSITION;
    float2 uv:TEXCOORD0;
};

struct v2f
{
    float2 uv:TEXCOORD0;
    float4 vertex:SV_POSITION;
};

sampler2D _MainTex;
float4 _MainTex_ST;
float4 _ColorTint;

v2f vert (appdata v)
{
    v2f o;
    o.vertex = TransformObjectToHClip(v.vertex);
    o.uv = v.uv;
    return o;
}

float4 frag (v2f i):SV_TARGET
{
    float4 col = tex2D(_MainTex, i.uv) * _ColorTint;
    return col;
}