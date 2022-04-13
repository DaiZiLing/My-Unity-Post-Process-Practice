//3、Pass，后处理的主要部分，我们的各种算法在这里实现。

Shader "PostPrecess/ColorTint"
{
    Properties
    {
        _MainTex ("基础贴图", 2D) = "white" {}
        _ColorTint("颜色", Color) = (1, 1, 1, 1)
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Assets/MyPostProcess/HimeColorTintFunction.hlsl"
    ENDHLSL 

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline"}
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM 
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
    }
}