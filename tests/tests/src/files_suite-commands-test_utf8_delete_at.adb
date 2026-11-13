separate (Files_Suite.Commands)
   procedure Test_Utf8_Delete_At (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  "a", e-acute (two bytes), "b".
      Accented : constant String :=
        Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("a" & Wide_Wide_Character'Val (16#E9#) & "b");
      --  "e" with a combining acute accent (two bytes), then "x".
      Combined : constant String :=
        Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("e" & Wide_Wide_Character'Val (16#301#) & "x");
      Words    : constant String := "alpha beta-gamma";
      New_Text   : Unbounded_String;
      New_Cursor : Natural;

      procedure Check
        (Text            : String;
         Cursor          : Natural;
         Backward        : Boolean;
         By_Word         : Boolean;
         Expected_Text   : String;
         Expected_Cursor : Natural;
         Context         : String) is
      begin
         Guikit.Utf8.Editing.Delete_At (Text, Cursor, Backward, By_Word, New_Text, New_Cursor);
         Assert_Equal (To_String (New_Text), Expected_Text, Context & ": text");
         Assert_Equal (New_Cursor, Expected_Cursor, Context & ": cursor");
      end Check;
   begin
      Check ("ab", 2, True, False, "a", 1, "Backspace deletes the character before the caret");
      Check ("ab", 0, True, False, "ab", 0, "Backspace at the start deletes nothing");
      Check ("ab", 0, False, False, "b", 0, "Delete deletes the character after the caret");
      Check ("ab", 2, False, False, "ab", 2, "Delete at the end deletes nothing");
      Check ("", 0, True, True, "", 0, "an empty field deletes nothing");
      Check (Accented, 3, True, False, "ab", 1, "Backspace deletes a whole multibyte character");
      Check (Accented, 1, False, False, "ab", 1, "Delete deletes a whole multibyte character");
      Check (Combined, 3, True, False, "x", 0, "Backspace deletes a base character with its combining mark");
      Check (Words, Words'Length, True, True, "alpha beta-", 11, "word Backspace deletes the word before the caret");
      Check
        (Words, 0, False, True,
         Guikit.Utf8.Editing.Remove_Range (Words, 0, Guikit.Utf8.Editing.Next_Word_Boundary (Words, 0)), 0,
         "word Delete deletes to the next word boundary");
      Assert (Length (New_Text) < Words'Length, "word Delete removes something");
   end Test_Utf8_Delete_At;
