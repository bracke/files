separate (Files_Suite.Operations)
   --  The 64 KiB a content search reads can end inside a character: what is
   --  searched is cut back to a whole one, and folding a text with a stray
   --  byte still folds the rest, so a mixed-case match in another script is
   --  found ahead of the cut.
   procedure Test_Content_Search_Utf8_Cut (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Greeting : constant String := Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("Привет ");
      Upper    : constant String := Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("ПРИВЕТ");
      Lower    : constant String := Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("привет");
      Zhe      : constant String := Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ("ж");
      Lead     : constant Character := Zhe (Zhe'First);
      Read_Cap : constant := 64 * 1024;
      Text     : String (1 .. Read_Cap + 20) := [others => 'a'];
      Search   : Files.File_System.Recursive_Search_Result;
   begin
      --  Folding keeps a stray byte and folds what surrounds it.
      Files_Suite.Support.Assert_Equal
        (Files.Types.Fold_Case (Upper & Lead), Lower & Lead, "a stray trailing byte does not stop the folding");
      Files_Suite.Support.Assert_Equal
        (Files.Types.Fold_Case (Lead & Upper), Lead & Lower, "a stray leading byte does not stop the folding");
      Files_Suite.Support.Assert_Equal
        (Files.Types.Trim_To_Character ("ab" & Lead), "ab", "a cut character is trimmed");
      Files_Suite.Support.Assert_Equal
        (Files.Types.Trim_To_Character ("ab" & Zhe), "ab" & Zhe, "a whole character is kept");

      --  The greeting early on; from byte Read_Cap two-byte characters, so
      --  the read's last byte is the first half of one.
      Text (1 .. Greeting'Length) := Greeting;
      declare
         Index : Positive := Read_Cap;
      begin
         while Index + 1 <= Text'Last loop
            Text (Index .. Index + 1) := Zhe;
            Index := Index + 2;
         end loop;
      end;
      Assert (Text (Read_Cap) = Lead, "the fixture splits a character at the read's end");
      Reset_Root;
      Write_Binary_File (Join (Root, "cyrillic.txt"), Text);
      Search := Files.File_System.Search_Contents (Root, Lower, Settings);
      Assert (Search.Success, "the content search succeeds");
      Files_Suite.Support.Assert_Equal
        (Natural (Search.Items.Length), 1, "a lower-case query finds the capitalised Cyrillic word");
      Assert (not Search.Incomplete and then not Search.Truncated, "and the answer is complete");
   end Test_Content_Search_Utf8_Cut;
