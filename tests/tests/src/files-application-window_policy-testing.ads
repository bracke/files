--  What the suite reaches of Files.Application.Window_Policy that is not part of its interface.
package Files.Application.Window_Policy.Testing is

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

end Files.Application.Window_Policy.Testing;
