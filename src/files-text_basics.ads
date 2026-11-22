with Files.Types;

--  Small text helpers every layer uses: a count without its blank, a
--  trimmed field, a prefix test and a split path list.
package Files.Text_Basics is

   --  A count in decimal, without the leading blank Natural'Image gives it.
   --
   --  @param Value Count to print.
   --  @return Its decimal digits.
   function Natural_Text (Value : Natural) return String;

   --  A whole number in decimal: "-12" with its sign, "12" without the
   --  blank Long_Long_Integer'Image gives a positive one.
   --
   --  @param Value Number to print.
   --  @return Its sign and decimal digits.
   function Integer_Text (Value : Long_Long_Integer) return String;

   --  Text without the spaces, tabs and carriage returns around it, as a
   --  line of a settings or desktop-entry file is read.
   --
   --  @param Text A line or a field of one.
   --  @return Text trimmed.
   function Trim_Blanks (Text : String) return String;

   --  The entries of a path list such as XDG_DATA_DIRS or PATH, split on
   --  Separator: ':' on POSIX hosts, ';' on Windows, where ':' is part of a
   --  drive letter. Empty entries are kept, so a caller can skip them as it
   --  does any unusable entry.
   --
   --  @param List The list's text.
   --  @param Separator The host's path-list separator.
   --  @return The entries in order.
   function Split_Path_List (List : String; Separator : Character) return Files.Types.String_Vectors.Vector;

   --  @param Text Text to inspect.
   --  @param Prefix Bytes Text must begin with.
   --  @return True when Text begins with exactly Prefix.
   function Starts_With (Text : String; Prefix : String) return Boolean is
     (Text'Length >= Prefix'Length
      and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

   --  A byte count grown by Amount without overflowing: a sum past
   --  Long_Long_Integer'Last stays there, and an Amount that is not
   --  positive leaves Total as it is. Sizes are summed this way everywhere
   --  (a folder's walk, a selection's total), so a huge tree caps instead of
   --  raising.
   --
   --  @param Total Running total.
   --  @param Amount Bytes to add.
   --  @return Total plus Amount, capped at Long_Long_Integer'Last.
   function Saturating_Add (Total, Amount : Long_Long_Integer) return Long_Long_Integer is
     (if Amount <= 0 then Total
      elsif Total > Long_Long_Integer'Last - Amount then Long_Long_Integer'Last
      else Total + Amount);
end Files.Text_Basics;
