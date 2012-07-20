package away3d.filters.effects
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.managers.Stage3DProxy;
	import away3d.errors.AbstractMethodError;

	use namespace arcane;

	public class PostEffectBase
	{
		protected var _needsNormals : Boolean;
		protected var _needsDepth : Boolean;
		protected var _needsPosition : Boolean;

		public function PostEffectBase()
		{
		}

		/**
		 * Things to know:
		 * v0 contains UV coords for current pixel
		 * v1 contains view direction
		 * fs0 and fs1 are reserved
		 * ft0, ft1 and ft2 are reserved
		 * ft0.xyz contains the normal, ft0.w contains the depth
		 * ft1 contains the view position
		 * output needs to write to and read from ft2 as source and target data
		 * fc0 and fc1 are reserved
		 */
		arcane function getFragmentCode(constantOffset : int) : String
		{
			throw new AbstractMethodError();
		}

		arcane function get needsNormals() : Boolean
		{
			return _needsNormals;
		}

		arcane function get needsDepth() : Boolean
		{
			return _needsDepth;
		}

		arcane function get needsPosition() : Boolean
		{
			return _needsPosition;
		}

		arcane function get numUsedFragmentConsts() : int
		{
			throw new AbstractMethodError();
			return 0;
		}

		arcane function activate(stage3DProxy : Stage3DProxy, camera : Camera3D) : void
		{
		}

		arcane function deactivate(stage3DProxy : Stage3DProxy) : void
		{
		}
	}
}
