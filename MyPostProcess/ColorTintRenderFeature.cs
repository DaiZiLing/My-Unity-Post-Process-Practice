//屏幕后处理效果思路：
//先拿一张目前有的帧，丢到shader里，处理这一张屏幕同款同高的面片，进行blabla处理
//然后再把它送回去。
//感觉很像PS的滤镜或者“游戏画质增强器——reshade”，不过三维场景的后处理花样要丰富得多

//URP的后处理和入门精要里的biult-in不一样，之前是往摄影机上面挂script。
//URP里是较为现代一点的Volume，PostProcessVolume那一套。如果我们想新增自己喜欢的后处理，得做以下三个部分
//1、VolumeComponent，用来给美工调参【HimeColorTint.cs】
//2、RenderFeature，用做搭建渲染的逻辑，设置shader（模板）【ColorTint.shader】
//3、Pass，后处理的主要部分，后处理模块都在这里。【HimeColorTintFeature.cs】

//2、RenderFeature，用做搭建渲染的逻辑，设置shader（模板）
//一、设置渲染事件
//二、同步渲染事件
//三：执行函数，汇入volume，汇入command
//四：Render函数，后处理逻辑

//教程：https://zhuanlan.zhihu.com/p/373273390
//Scriptable Renderer Feature 由 CustomRenderPassFeature 与 CustomRenderPass 组成。
//继承：ScriptableRendererFeature → CustomRenderPassFeature，ScriptableRenderPass → CustomRenderPass

using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

//【用于渲染管线设置里的用户界面】
//一个feature，一个pass
public class ColorTintRenderFeature : ScriptableRendererFeature
{
    [System.Serializable] //脚本序列化
    //https://docs.unity3d.com/ScriptReference/Serializable.html

    public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        //避免我们写的东西与URP自身的东西干扰，所以我们写的东西默认在URP的后处理之前
        //为何要做这个enum？因为有时我们并不想让透明物体也被描边。即对render queue进行判断。
        public Shader shader; //汇入shader。
    }

    public Settings settings = new Settings(); //开放设置

    //【我们主要在这里做pass ↓ ↓ ↓】
    ColorTintPass colorTintPass;//【pass】
    //【我们主要在这里做pass ↑ ↑ ↑】

    public override void Create() //新建pass
    {
        this.name = "ColorTintPass"; //你的名字
        colorTintPass = new ColorTintPass(RenderPassEvent.BeforeRenderingPostProcessing, settings.shader); //初始化，上面那个东西的shader
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) //Pass逻辑
    {
        colorTintPass.Setup(renderer.cameraColorTarget); //初始化
        renderer.EnqueuePass(colorTintPass); //汇入render queue
    }
}

//【pass】
public class ColorTintPass : ScriptableRenderPass
{
    static readonly string k_RenderTag = "ColorTint Effects";

    static readonly int TempTargetId = Shader.PropertyToID("_TempTargetColorTint");
    static readonly int MainTexId = Shader.PropertyToID("_MainTex"); //暂存

    ColorTint colorTint;
    Material colorTintMaterial;
    RenderTargetIdentifier currentTarget;

    int[] downSampleRT;
    int[] upSampleRT;

    //【渲染事件】
    #region RenderEvent
    public ColorTintPass(RenderPassEvent evt, Shader ColorTintShader)
    {
        renderPassEvent = evt;
        var shader = ColorTintShader; //

        if (shader == null)
        {
            Debug.LogError("There is no ColorTint Shader!");
            return;
        }

        colorTintMaterial = CoreUtils.CreateEngineMaterial(ColorTintShader); //新建材质
    }
    #endregion

    //【初始化】
    #region Initialize
    public void Setup(in RenderTargetIdentifier currentTarget)
    {
        this.currentTarget = currentTarget;
    }
    #endregion
    //初始化结束

    //【执行】
    #region Execute
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (colorTintMaterial == null) //如果材质不存在
        {
            Debug.LogError("There is no Color Tint Material!");
            return;
        }

        if (!renderingData.cameraData.postProcessEnabled) //如果摄影机没开后处理
        {
            return;
        }

        var stack = VolumeManager.instance.stack;
        colorTint = stack.GetComponent<ColorTint>(); //把用户设置的颜色给volume

        if (colorTint == null)
        {
            Debug.LogError("Get Volume Component failed...");
            return;
        }

        var cmd = CommandBufferPool.Get(k_RenderTag); //拿到profilerTag

        //【我们主要在这里做render ↓ ↓ ↓】
        Render(cmd, ref renderingData); //渲染函数，下面那一个region【渲染】
        //【我们主要在这里做render ↑ ↑ ↑】

        context.ExecuteCommandBuffer(cmd); //执行函数，回收
        CommandBufferPool.Release(cmd);
    }
    #endregion

    // //【渲染】
    // #region Rendering
    // void Render(CommandBuffer cmd, ref RenderingData renderingData)
    // {
    //     ref var cameraData = ref renderingData.cameraData;
    //     var camera = cameraData.camera;
    //     var source = currentTarget; //当前帧以图片汇入
    //     int destination = TempTargetId; //中途使用的渲染目的地

    //     colorTintMaterial.SetColor("_ColorTint", colorTint.colorChange.value);
    //     colorTintMaterial.SetFloat("_BlurRange", colorTint.BlurRange.value);//汇入颜色校正

    //     cmd.SetGlobalTexture(MainTexId, source);

    //     cmd.GetTemporaryRT
    //     (
    //         destination,
    //         cameraData.camera.scaledPixelWidth / colorTint.RTDownSampling.value, //宽，可以降采样
    //         cameraData.camera.scaledPixelHeight / colorTint.RTDownSampling.value, //高，可以降采样
    //         0,
    //         FilterMode.Trilinear, //三线性
    //         RenderTextureFormat.Default
    //     );

    //     //设置color tint render target
    //     cmd.Blit(source, destination);
    //     cmd.Blit(destination, source, colorTintMaterial, 0);//叠一次ColorTint，第一个pass

    //     for (int i = 0; i < colorTint.BlurTimes.value; i++)//单pass模糊
    //     {
    //         cmd.Blit(source, destination);
    //         cmd.Blit(destination, source, colorTintMaterial, 1);
    //     }

    // }
    // #endregion

//    【这一坨是DualKawase渲染】
    #region DualKawaseRendering
    void Render(CommandBuffer cmd, ref RenderingData renderingData)
    {
        ref var cameraData = ref renderingData.cameraData;
        var camera = cameraData.camera;
        var source = currentTarget; //当前帧以图片汇入
        int destination = TempTargetId; //中途使用的渲染目的地

        RenderTargetIdentifier sourceRT = source;
        RenderTextureDescriptor inRTDesc = renderingData.cameraData.cameraTargetDescriptor;
        inRTDesc.depthBufferBits = 0;
        
        int tw = (int)inRTDesc.width / colorTint.RTDownSampling.value;
        int th = (int)inRTDesc.height / colorTint.RTDownSampling.value;
        downSampleRT = new int[colorTint.BlurTimes.value];
        upSampleRT = new int[colorTint.BlurTimes.value];
        
        colorTintMaterial.SetColor("_ColorTint", colorTint.colorChange.value);
        colorTintMaterial.SetFloat("_BlurRange", colorTint.BlurRange.value);//汇入颜色校正

        cmd.SetGlobalTexture(MainTexId, source);
        cmd.GetTemporaryRT (destination, tw, th, 0, FilterMode.Trilinear, RenderTextureFormat.Default);
        //设置color tint render target

        cmd.Blit(source, destination);
        cmd.Blit(destination, source, colorTintMaterial, 0);//叠一次ColorTint，第一个pass

        for(int i = 0; i < colorTint.BlurTimes.value; i++)
        {
            downSampleRT[i] = Shader.PropertyToID("DownSample" + i);
            upSampleRT[i] = Shader.PropertyToID("UpSample" + i);
        }

        RenderTargetIdentifier tmpRT = sourceRT;

        //DownSample
        for (int i = 0; i < colorTint.BlurTimes.value; i++)
        {
            cmd.GetTemporaryRT(downSampleRT[i], tw, th, 0, FilterMode.Bilinear, RenderTextureFormat.Default);
            cmd.GetTemporaryRT(upSampleRT[i], tw, th, 0, FilterMode.Bilinear, RenderTextureFormat.Default);
            tw = Mathf.Max(tw / 2, 1);
            th = Mathf.Max(th / 2, 1);
        
            cmd.Blit(tmpRT, downSampleRT[i], colorTintMaterial, 2);
            tmpRT = downSampleRT[i];

        }

        //UpSample
        for (int i = colorTint.BlurTimes.value - 1; i >= 0; i--)
        {
            //cmd.GetTemporaryRT(upSampleRT[i], tw, th, 0, FilterMode.Bilinear, RenderTextureFormat.Default);
            //tw = Mathf.Max(tw * 2, 1);
            //th = Mathf.Max(th * 2, 1);
       
            cmd.Blit(tmpRT, upSampleRT[i], colorTintMaterial, 3);
            tmpRT = upSampleRT[i];

        }

        // //final pass
        cmd.Blit(tmpRT, source);  

        //Release All tmpRT
        for (int i = 0; i < colorTint.BlurTimes.value; i++)
        {
            cmd.ReleaseTemporaryRT(downSampleRT[i]);
            cmd.ReleaseTemporaryRT(upSampleRT[i]);
        }
    }
    #endregion

    // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
    {

    }
}
