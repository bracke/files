with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

--  Shared value types used across the files model, commands, and rendering.
package Files.Types is
   subtype UString is Ada.Strings.Unbounded.Unbounded_String;

   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => UString,
      "="          => Ada.Strings.Unbounded."=");

   type View_Mode is
     (Small_Icons,
      Large_Icons,
      Details);

   type Item_Kind is
     (Directory_Item,
      Regular_File_Item,
      Symlink_Item,
      Executable_Item,
      Unknown_Item,
      Other_Item);

   type Navigation_Direction is
     (Move_Left,
      Move_Right,
      Move_Up,
      Move_Down);

   type Modifier_Key is
     (Shift_Key,
      Control_Key,
      Alt_Key,
      Meta_Key);

   type Modifier_Set is array (Modifier_Key) of Boolean;

   No_Modifiers : constant Modifier_Set := [others => False];

   type Key_Code is
     (Key_Unknown,
      Key_1,
      Key_2,
      Key_3,
      Key_4,
      Key_D,
      Key_F,
      Key_L,
      Key_N,
      Key_P,
      Key_R,
      Key_S,
      Key_Backspace,
      Key_Delete,
      Key_F2,
      Key_Escape,
      Key_Return,
      Key_Left,
      Key_Right,
      Key_Up,
      Key_Down,
      Key_Home,
      Key_End,
      Key_Page_Up,
      Key_Page_Down);

   type Focus_Target is
     (Focus_None,
      Focus_Path_Input,
      Focus_Filter_Input,
      Focus_Rename_Input,
      Focus_Command_Palette,
      Focus_Settings_Input);

   --  Return Text converted to lower case using simple Ada character folding.
   --
   --  @param Text Text to normalize.
   --  @return Lower-case version of Text.
   function To_Lower (Text : String) return String;

   --  Return whether Needle occurs in Haystack after case folding.
   --
   --  @param Haystack Text to search.
   --  @param Needle Text to find.
   --  @return True when Needle occurs in Haystack case-insensitively.
   function Contains_Case_Insensitive
     (Haystack : String;
      Needle   : String)
      return Boolean;
end Files.Types;
