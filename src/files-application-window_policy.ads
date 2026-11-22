with Files.Input_Actions;
with Ada.Real_Time;

with Files.UI_Types;
with Glfw;
with Glfw.Input.Mouse;
with Guikit.Input;
with Guikit.Settings_Panel;

--  The window layer's decisions that need no window: what the host offers a
--  desktop run, which held keys repeat, what typed characters and wheel
--  steps become, where a pointer lands in the frame (scaled to framebuffer
--  pixels, reflected in a mirrored layout), when a press becomes a drag, how
--  many framebuffer pixels a window pixel is, the text size that gives, what
--  an assistive technology's request does, and when a wheel zoom is saved.
--  Files.Application.Windows applies them to GLFW and Vulkan; here they are
--  unit-tested.
package Files.Application.Window_Policy is

   --  What this host offers a desktop run, found without opening a window.
   type Desktop_Capabilities is record
      Display_Available       : Boolean := False;
      Vulkan_Available        : Boolean := False;
      Live_Window_Smoke_Ready : Boolean := False;
   end record;

   --  The capabilities a host with this display and this Vulkan has: a live
   --  window smoke needs both.
   --
   --  @param Display Whether a window can be shown.
   --  @param Vulkan Whether Vulkan is usable.
   --  @return The capability flags.
   function Capabilities_Of (Display, Vulkan : Boolean) return Desktop_Capabilities is
     (Display_Available => Display, Vulkan_Available => Vulkan, Live_Window_Smoke_Ready => Display and then Vulkan);

   --  Accumulate a fractional scroll offset into whole scroll lines.
   --
   --  @param Remainder Fractional offset carried from previous callbacks.
   --  @param Offset New GLFW-style scroll offset to add.
   --  @return Whole scroll lines produced by the accumulated offset.
   function Accumulate_Scroll_Offset
     (Remainder : in out Long_Float;
      Offset    : Long_Float)
      return Integer;

   --  Add pending scroll line counts using saturation.
   --
   --  @param Current Pending scroll lines already queued.
   --  @param Change Newly accumulated scroll lines.
   --  @return Saturated sum of current and new scroll lines.
   function Add_Pending_Scroll
     (Current : Integer;
      Change  : Integer)
      return Integer;

   --  Encode a GLFW character callback value for the byte-oriented text controller.
   --
   --  Control characters and invalid Unicode scalar values are ignored.
   --
   --  @param Char Character callback value reported by GLFW.
   --  @return UTF-8 bytes to append to focused text input, or an empty string.
   function Text_Input_Bytes
     (Char : Wide_Wide_Character)
      return String;

   --  Scale a window-relative mouse coordinate into framebuffer coordinates.
   --
   --  @param Value Mouse coordinate in the source window dimension.
   --  @param Source Source window dimension.
   --  @param Target Target framebuffer dimension.
   --  @return Clamped target coordinate, or zero for invalid dimensions.
   function Scale_Coordinate
     (Value  : Glfw.Input.Mouse.Coordinate;
      Source : Glfw.Size;
      Target : Glfw.Size)
      return Natural;

   --  Scale_Coordinate for the pointer's X, reflected in a right-to-left
   --  (mirrored) layout so it names the column of the frame as drawn before
   --  mirroring, where layouts and hit tests work. A pointer past the right
   --  edge of a mirrored window (a drag held outside it) is past the drawn
   --  frame's left edge, column 0, as Guikit.Mirroring.Mirror_X maps it; a
   --  click there never reaches a hit test, which Cursor_Is_Inside_Window
   --  gates.
   --
   --  @param Value Mouse X in the source window width.
   --  @param Source Window width.
   --  @param Target Framebuffer width.
   --  @return The column hit tests use.
   function Scale_X
     (Value  : Glfw.Input.Mouse.Coordinate;
      Source : Glfw.Size;
      Target : Glfw.Size)
      return Natural;

   --  Convert a scrollbar thumb position into its logical scroll offset.
   --
   --  Thumb_Top is relative to the beginning of the track. Positions beyond
   --  the usable thumb travel are clamped, so the bottom of the track maps to
   --  Maximum exactly even when the content's final page is partial.
   --
   --  @param Thumb_Top Relative top of the dragged thumb.
   --  @param Track_Length Total scrollbar track length.
   --  @param Thumb_Length Length of the draggable thumb.
   --  @param Maximum Largest valid logical scroll offset.
   --  @return Proportional logical offset in the range 0 .. Maximum.
   function Scrollbar_Drag_Offset
     (Thumb_Top    : Natural;
      Track_Length : Natural;
      Thumb_Length : Natural;
      Maximum      : Natural)
      return Natural;

   --  Return whether raw GLFW cursor coordinates name a pixel inside a window.
   --  Test this before scaling: Scale_Coordinate clamps negative values to zero,
   --  which intentionally loses the distinction between outside-left/top and
   --  the first pixel.
   --
   --  @param X Raw horizontal cursor coordinate.
   --  @param Y Raw vertical cursor coordinate.
   --  @param Width Window width in screen coordinates.
   --  @param Height Window height in screen coordinates.
   --  @return True when the coordinate lies inside the half-open window bounds.
   function Cursor_Is_Inside_Window
     (X      : Glfw.Input.Mouse.Coordinate;
      Y      : Glfw.Input.Mouse.Coordinate;
      Width  : Glfw.Size;
      Height : Glfw.Size)
      return Boolean;

   --  How far, in window pixels, the pointer travels with the button down
   --  before a press becomes a drag: a file drag, a column reorder or a
   --  marquee alike. Below it the press is a click.
   Drag_Distance : constant := 5;

   --  Whether the pointer has travelled far enough from its press for a drag.
   --
   --  @param Delta_X Horizontal travel, in pixels.
   --  @param Delta_Y Vertical travel, in pixels.
   --  @param Pixel_Ratio Pixels the travel is counted in per window pixel:
   --    1.0 for window coordinates, Pixel_Ratio for framebuffer ones, so a
   --    drag is as far for the hand on a 2x display as on 1x.
   --  @return True once either travel reaches Drag_Distance window pixels.
   function Is_Drag (Delta_X, Delta_Y : Long_Float; Pixel_Ratio : Float) return Boolean is
     (abs Delta_X >= Long_Float (Drag_Distance) * Long_Float (Pixel_Ratio)
      or else abs Delta_Y >= Long_Float (Drag_Distance) * Long_Float (Pixel_Ratio));

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
     (Click    : Files.Input_Actions.Input_Action;
      Activate : Boolean)
      return Files.Input_Actions.Input_Action;

   --  The text field a screen reader's request for a node names
   --  (Files.Events.Translate_Field_Request), with the node's box as shown,
   --  reflected back first in a mirrored layout.
   --
   --  @param X The node's left edge as shown, in framebuffer pixels.
   --  @param Y The node's top edge.
   --  @param Width The node's width.
   --  @param Height The node's height.
   --  @param Frame_Width The frame's width.
   --  @param Line_Height Row height in pixels.
   --  @return Focusing that field, or no action for any other node.
   function Field_Request
     (X, Y, Width, Height : Natural;
      Frame_Width         : Natural;
      Line_Height         : Positive)
      return Files.Input_Actions.Input_Action;

   --  Whether an Activate request also presses Space: on a focused settings
   --  toggle or choice, which a click on its row's middle only focuses.
   --
   --  @param Activate True for an Activate request.
   --  @param Focus Where the window's keyboard focus is.
   --  @param Field The focused settings field's kind.
   --  @return True when Space should follow.
   function Activation_Presses_Space
     (Activate : Boolean;
      Focus    : Files.UI_Types.Focus_Target;
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

   --  The dragged item's visible index now. The index taken at the press
   --  stands while the rows are those it was taken from; once they moved (a
   --  watched refresh reordering the list mid-drag) it would name another
   --  item, so the item is found again by its path, and an item gone since
   --  ends the drag (0).
   --
   --  @param Index The visible index the drag knows, 0 for no drag.
   --  @param Index_Rows The rows revision Index was taken at.
   --  @param Rows The model's rows revision now.
   --  @param Path The dragged item's full path.
   --  @param Index_Of The visible index of an item by its path, 0 if none.
   --  @return The dragged item's visible index, or 0.
   function Drag_Source_Now
     (Index      : Natural;
      Index_Rows : Natural;
      Rows       : Natural;
      Path       : String;
      Index_Of   : not null access function (Path : String) return Natural)
      return Natural is
     (if Index = 0 or else Index_Rows = Rows then Index else Index_Of (Path));

private

   --  The X of a screen reader's node box in the frame as drawn before
   --  mirroring: the tree a screen reader is given is the shown one, which a
   --  right-to-left (mirrored) layout reflects, while layouts and hit tests
   --  work unmirrored. A box reaching past the frame stays where it is.
   --
   --  @param X The box's left edge as shown.
   --  @param Width The box's width.
   --  @param Frame_Width The frame's width.
   --  @return The box's left edge as drawn.
   function Unmirrored_Node_X (X, Width, Frame_Width : Natural) return Natural;

end Files.Application.Window_Policy;
