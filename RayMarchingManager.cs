using System.Collections;
using System.Collections.Generic;
using NodeNotes_Visual.ECS;
using PlayerAndEditorGUI;
using QuizCannersUtilities;
using UnityEngine;
using System;

#if UNITY_EDITOR
using UnityEditor;
#endif

namespace RayMarching
{

    [ExecuteAlways]
    public class RayMarchingManager : MonoBehaviour, IPEGI, ICfg
    {
     
        LinkedLerp.MaterialFloat _rayMarchSmoothness = new LinkedLerp.MaterialFloat("_RayMarchSmoothness", 1, 30);
        LinkedLerp.MaterialFloat _rayMarchShadowSoftness = new LinkedLerp.MaterialFloat("_RayMarchShadowSoftness", 1, 30);
        LinkedLerp.MaterialColor _RayMarchLightColor = new LinkedLerp.MaterialColor("_RayMarchLightColor", Color.grey, 10);

        [NonSerialized] private QcUtils.DynamicRangeFloat smoothness = new QcUtils.DynamicRangeFloat(0.01f, 10, 1);
        [NonSerialized] private QcUtils.DynamicRangeFloat shadowSoftness = new QcUtils.DynamicRangeFloat(0.01f, 10, 1);
        [NonSerialized] private Color _lightColor = Color.grey;

        [SerializeField] private RayMarchingConfigs configs;

        LerpData ld =new LerpData();

        public void Update()
        {
            ld.Reset();

            var cfg = RayMarchingConfig.ActiveConfig;

            _rayMarchSmoothness.Portion(ld, smoothness.Value);
            _RayMarchLightColor.Portion(ld, _lightColor);
            _rayMarchShadowSoftness.Portion(ld, shadowSoftness.Value);

            _rayMarchSmoothness.Lerp(ld);
            _RayMarchLightColor.Lerp(ld);
            _rayMarchShadowSoftness.Lerp(ld);
        }

        #region Inspector
        public static RayMarchingManager inspected;
        
        public bool Inspect()
        {

            inspected = this;

            "Smoothness:".nl();
            smoothness.Inspect().nl();
            "Shadow Softness".nl();
            shadowSoftness.Inspect().nl();
            "Light Color".edit(ref _lightColor).nl();


            ConfigurationsListBase.Inspect(ref configs);

            return false;
        }
        #endregion

        #region Encode & Decode
        public CfgEncoder Encode() => new CfgEncoder()
            .Add("sm", smoothness)
            .Add("col", _lightColor)
            .Add("shSo", shadowSoftness);
        
        public bool Decode(string tg, string data)
        {
            switch (tg)
            {
                case "sm": smoothness.Decode(data); break;
                case "col": _lightColor = data.ToColor(); break;
                case "shSo": shadowSoftness.Decode(data); break;


                default: return false;
            }

            return true;
        }

        public void Decode(string data) => new CfgDecoder(data).DecodeTagsFor(this);
        #endregion
    }





#if UNITY_EDITOR
    [CustomEditor(typeof(RayMarchingManager))]
    public class RayMarchingManagerDrawer : PEGI_Inspector_Mono<RayMarchingManager> { }
#endif

}