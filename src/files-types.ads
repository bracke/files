with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Interfaces;

--  Shared value types used across the files model, commands, and rendering.
package Files.Types is
   subtype UString is Ada.Strings.Unbounded.Unbounded_String;

   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => UString,
      "="          => Ada.Strings.Unbounded."=");

   package Byte_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Interfaces.Unsigned_8,
      "="          => Interfaces."=");

   type View_Mode is
     (Small_Icons,
      Large_Icons,
      Details);

   --  Selectable detail-view columns. The name column is always shown and
   --  cannot be hidden; the remaining columns are individually toggleable and,
   --  when visible, laid out left to right in this declaration order.
   type Detail_Column is
     (Name_Column,
      Modified_Column,
      Size_Column,
      Filetype_Column,
      Created_Column,
      Permissions_Column);

   --  Toggleable detail columns, i.e. every column except the mandatory name.
   subtype Optional_Detail_Column is
     Detail_Column range Modified_Column .. Permissions_Column;

   --  Per-column visibility flags for the detail view.
   type Detail_Column_Visibility is array (Detail_Column) of Boolean;

   --  Per-column pixel widths for the detail view. A width of zero means the
   --  layout derives a proportional default for that column.
   type Detail_Column_Widths is array (Detail_Column) of Natural;

   --  Default detail-column visibility: name, modified, size, and type are
   --  shown; created and permissions stay hidden until enabled.
   Default_Detail_Column_Visibility : constant Detail_Column_Visibility :=
     [Name_Column        => True,
      Modified_Column    => True,
      Size_Column        => True,
      Filetype_Column    => True,
      Created_Column     => False,
      Permissions_Column => False];

   --  Default per-column widths: zero for every column so the layout derives
   --  proportional defaults until a width is customized.
   Default_Detail_Column_Widths : constant Detail_Column_Widths := [others => 0];

   --  Smallest pixel width a customized detail column may occupy.
   Minimum_Detail_Column_Width : constant := 48;

   --  Detail-view row grouping mode. When it is not No_Grouping the detail list
   --  gains non-selectable group header rows composed with the active sort.
   type Group_Mode is
     (No_Grouping,
      Group_By_Type,
      Group_By_Modified,
      Group_By_Size);

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
      Key_A,
      Key_C,
      Key_D,
      Key_F,
      Key_L,
      Key_N,
      Key_P,
      Key_R,
      Key_S,
      Key_V,
      Key_X,
      Key_Z,
      Key_Comma,
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
      Key_Page_Down,
      Key_Space);

   type Focus_Target is
     (Focus_None,
      Focus_Path_Input,
      Focus_Filter_Input,
      Focus_Rename_Input,
      Focus_Command_Palette,
      Focus_Settings_Input);

   --  Return Text converted to lower case using simple Ada character folding
   --  plus common UTF-8 Latin-1 uppercase letters.
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
