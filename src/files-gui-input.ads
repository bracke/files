--  Domain-free keyboard and pointer input primitives.
--
--  These generic input value types (key codes, modifier keys, and directional
--  navigation) describe raw user input independently of any file-manager
--  domain concept. They live under Files.Gui so the presentation and input
--  layer stays free of dependencies on the model, settings, commands, and
--  other domain packages; the compiler enforces that boundary.
package Files.Gui.Input is

   --  A discrete movement direction produced by directional keys, used to
   --  drive selection, caret, and settings-field navigation.
   type Navigation_Direction is
     (Move_Left,
      Move_Right,
      Move_Up,
      Move_Down);

   --  A keyboard modifier key. Modifier state is tracked per key rather than
   --  as an opaque mask so platform bindings can map each key independently.
   type Modifier_Key is
     (Shift_Key,
      Control_Key,
      Alt_Key,
      Meta_Key);

   --  The set of modifier keys held down for an input event.
   type Modifier_Set is array (Modifier_Key) of Boolean;

   --  The empty modifier set: no modifier keys held.
   No_Modifiers : constant Modifier_Set := [others => False];

   --  A logical keyboard key, abstracted from platform-specific scan codes.
   type Key_Code is
     (Key_Unknown,
      Key_0,
      Key_1,
      Key_2,
      Key_3,
      Key_4,
      Key_A,
      Key_B,
      Key_C,
      Key_D,
      Key_F,
      Key_I,
      Key_L,
      Key_N,
      Key_P,
      Key_R,
      Key_S,
      Key_V,
      Key_X,
      Key_Z,
      Key_Comma,
      Key_Equal,
      Key_Minus,
      Key_Backspace,
      Key_Delete,
      Key_F2,
      Key_F5,
      Key_Escape,
      Key_Return,
      Key_Left,
      Key_Right,
      Key_Up,
      Key_Down,
      Key_Home,
      Key_End,
      Key_Page_Up,
      Key_Page_Down,
      Key_Space);

end Files.Gui.Input;
