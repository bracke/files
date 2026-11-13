with Guikit.Utf8.Editing;

--  Nothing is implemented here: display width, codepoint decoding and the
--  whitespace rule are Guikit.Utf8's, and the caret/word boundaries, range
--  removal and the shared deletion rule are Guikit.Utf8.Editing's, so the
--  file manager's text fields and the toolkit's own (the command palette's
--  query) edit by one rule that cannot drift.
package body Files.UTF8 is

   function Display_Units
     (Content : String)
      return Natural
     renames Guikit.Utf8.Display_Units;

   function Prefix_By_Units
     (Content   : String;
      Max_Units : Natural)
      return String
     renames Guikit.Utf8.Prefix_By_Units;

   function Display_Units_Before
     (Content : String;
      Cursor  : Natural)
      return Natural
     renames Guikit.Utf8.Display_Units_Before;

   function Byte_Offset_For_Display_Column
     (Content : String;
      Column  : Natural)
      return Natural
     renames Guikit.Utf8.Byte_Offset_For_Display_Column;

   procedure Decode_Next_Codepoint
     (Content               : String;
      Index                 : in out Integer;
      Codepoint             : out Natural;
      Replacement_Codepoint : Natural := 16#FFFD#)
     renames Guikit.Utf8.Decode_Next_Codepoint;

   function Is_Valid
     (Content : String)
      return Boolean
     renames Guikit.Utf8.Is_Valid;

   function Previous_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
     renames Guikit.Utf8.Editing.Previous_Boundary;

   function Next_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
     renames Guikit.Utf8.Editing.Next_Boundary;

   function Boundary_At_Or_Before
     (Content : String;
      Cursor  : Natural)
      return Natural
     renames Guikit.Utf8.Editing.Boundary_At_Or_Before;

   function Whitespace_Separator_Length
     (Content  : String;
      Position : Natural)
      return Natural
     renames Guikit.Utf8.Whitespace_Separator_Length;

   function Word_Separator_Length
     (Content  : String;
      Position : Natural)
      return Natural
     renames Guikit.Utf8.Editing.Word_Separator_Length;

   function Previous_Word_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
     renames Guikit.Utf8.Editing.Previous_Word_Boundary;

   function Next_Word_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
     renames Guikit.Utf8.Editing.Next_Word_Boundary;

   function Remove_Range
     (Content : String;
      First   : Natural;
      Last    : Natural)
      return String
     renames Guikit.Utf8.Editing.Remove_Range;

   procedure Delete_At
     (Text       : String;
      Cursor     : Natural;
      Backward   : Boolean;
      By_Word    : Boolean;
      New_Text   : out Ada.Strings.Unbounded.Unbounded_String;
      New_Cursor : out Natural)
     renames Guikit.Utf8.Editing.Delete_At;

end Files.UTF8;
