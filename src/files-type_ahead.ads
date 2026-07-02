with Files.File_System;

--  Pure type-to-select (type-ahead) matching over a visible item projection.
package Files.Type_Ahead is

   --  Return whether Name begins with Prefix, comparing case-insensitively.
   --
   --  Both operands are lower-cased with the shared UTF-8-aware folding helper
   --  before the leading bytes are compared, so ASCII and Latin-1 letters match
   --  regardless of case.
   --
   --  @param Name UTF-8 encoded candidate name.
   --  @param Prefix UTF-8 encoded prefix typed by the user.
   --  @return True when Name starts with Prefix (case-insensitive).
   function Starts_With_Case_Insensitive
     (Name   : String;
      Prefix : String)
      return Boolean;

   --  Return the visible index of the first item whose name starts with Prefix.
   --
   --  The search begins at Start_Index (one-based, inclusive) and wraps around
   --  to the front of the projection, so every item is considered exactly once.
   --  A Start_Index of zero, or one past the last item, begins the scan at the
   --  first item. Matching is case-insensitive and UTF-8 aware.
   --
   --  @param Items Visible items in display order.
   --  @param Prefix UTF-8 encoded prefix typed by the user.
   --  @param Start_Index One-based visible index to begin scanning from.
   --  @return One-based visible index of the first match, or zero when none
   --    match or Prefix is empty.
   function Type_Ahead_Target
     (Items       : Files.File_System.Item_Vectors.Vector;
      Prefix      : String;
      Start_Index : Natural)
      return Natural;

end Files.Type_Ahead;
