using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

//1、VolumeComponent，用来给美工调参

public class ColorTint : VolumeComponent
{
    public ColorParameter colorChange = new ColorParameter(Color.white, true);  //默认LDR白色

    public IntParameter BlurTimes = new ClampedIntParameter(1, 0, 10);  //模糊的迭代次数 0~10
    public FloatParameter BlurRange = new ClampedFloatParameter(1.0f, 0.0f, 10.0f);  //模糊半径
    public IntParameter RTDownSampling = new ClampedIntParameter(1, 1, 4);  //降采样次数
}
 