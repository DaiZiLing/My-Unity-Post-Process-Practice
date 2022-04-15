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

        Pass //ColorTint【pass 0】
        {
            HLSLPROGRAM 
            #pragma vertex ColorTintVert
            #pragma fragment ColorTintFrag
            ENDHLSL
        }

        Pass //Gaussian Box Kawase Blur【pass 1】
        {
            HLSLPROGRAM 
            #pragma vertex ColorTintVert
            #pragma fragment GaussianBlurFrag
            ENDHLSL
        }

        Pass //Dual Blur -- Down【pass 2】
        {
            Name "DownSample"
            HLSLPROGRAM 
            #pragma vertex DualBlurDownVert
            #pragma fragment DualBlurDownFrag
            ENDHLSL
        }

        Pass //Dual Blur -- Up【pass 3】
        {
            Name "UpSample"
            HLSLPROGRAM 
            #pragma vertex DualBlurUpVert
            #pragma fragment DualBlurUpFrag
            ENDHLSL
        }
    }
}