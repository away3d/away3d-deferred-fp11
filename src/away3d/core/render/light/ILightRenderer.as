package away3d.core.render.light
{
	import away3d.cameras.Camera3D;
	import away3d.core.managers.Stage3DProxy;
	import away3d.lights.LightBase;

	import flash.display3D.textures.TextureBase;

	public interface ILightRenderer
	{
		function render(light : LightBase, camera : Camera3D, stage3DProxy : Stage3DProxy, frustumCorners : Vector.<Number>, sourceBuffer : TextureBase = null) : void;
	}
}
