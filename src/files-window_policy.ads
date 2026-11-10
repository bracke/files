with Ada.Real_Time;

with Files.Events;
with Files.Types;
with Guikit.Input;
with Guikit.Settings_Panel;

--  The window layer's decisions that need no window: which held keys repeat,
--  how many framebuffer pixels a window pixel is, the text size that gives,
--  what an assistive technology's request does, and when a wheel zoom is
--  saved. Files.Application.Windows applies them to GLFW and Vulkan; here
--  they are unit-tested.
package Files.Window_Policy is

   --  Whether a held key repeats: only keys that move, delete or zoom do; a
   --  held Enter opens once, a held Space previews once.
   --
   --  @param Key The key, resolved through the keyboard layout.
   --  @return True when its system repeat is acted on.
   function Key_Repeats (Key : Guikit.Input.Key_Code) return Boolean is
     (Key in Guikit.Input.Key_Left | Guikit.Input.Key_Right | Guikit.Input.Key_Up | Guikit.Input.Key_Down
           | Guikit.Input.Key_Page_Up | Guikit.Input.Key_Page_Down
           | Guikit.Input.Key_Backspace | Guikit.Input.Key_Delete
           | Guikit.Input.Key_Equal | Guikit.Input.Key_Minus);

   --  Framebuffer pixels per window pixel (a Retina display, a scaled
   --  Wayland output), from 1 to 8.
   --
   --  @param Frame_Width The framebuffer's width.
   --  @param Window_Width The window's width.
   --  @param Current The ratio in use, kept while either width is unknown (0).
   --  @return The ratio to draw at.
   function Pixel_Ratio (Frame_Width, Window_Width : Natural; Current : Float) return Float is
     (if Window_Width > 0 and then Frame_Width > 0
      then Float'Min (8.0, Float'Max (1.0, Float (Frame_Width) / Float (Window_Width)))
      else Current);

   --  A text size setting in framebuffer pixels.
   --
   --  @param Size The setting, in window pixels.
   --  @param Ratio Pixel_Ratio.
   --  @return The pixel size glyphs are made at.
   function Scaled_Font_Size (Size : Positive; Ratio : Float) return Positive is
     (Positive'Max (1, Natural (Float (Size) * Ratio)));

   --  What an assistive technology's request does, given the click its
   --  node's centre would be: Activate opens an item (a double-click; Select
   --  and Focus only select it), and a column header sorts by its column
   --  rather than arming a drag no pointer will finish.
   --
   --  @param Click The click at the node's centre.
   --  @param Activate True for an Activate request.
   --  @return The action to dispatch.
   function Accessibility_Action
     (Click    : Files.Events.Input_Action;
      Activate : Boolean)
      return Files.Events.Input_Action;

   --  Whether an Activate request also presses Space: on a focused settings
   --  toggle or choice, which a click on its row's middle only focuses.
   --
   --  @param Activate True for an Activate request.
   --  @param Focus Where the window's keyboard focus is.
   --  @param Field The focused settings field's kind.
   --  @return True when Space should follow.
   function Activation_Presses_Space
     (Activate : Boolean;
      Focus    : Files.Types.Focus_Target;
      Field    : Guikit.Settings_Panel.Field_Kind)
      return Boolean;

   --  How long the wheel must rest before a zoom is saved: long enough to
   --  cover a pinch or a fast spin.
   Zoom_Save_Delay : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (500);

   --  Whether a wheel zoom is saved now.
   --
   --  @param Unsaved True while a zoom is not yet saved.
   --  @param Force True when it must be saved at once (a window closing).
   --  @param Now The current time.
   --  @param Zoomed_At When the wheel last zoomed.
   --  @return True when the settings should be written.
   function Zoom_Save_Due
     (Unsaved   : Boolean;
      Force     : Boolean;
      Now       : Ada.Real_Time.Time;
      Zoomed_At : Ada.Real_Time.Time)
      return Boolean;

end Files.Window_Policy;
