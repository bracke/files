separate (Files_Suite.Names)
   --  The one stem/extension split every "(copy)", "name 2" and link name
   --  uses: a recovered payload split "foo." into "foo" and "." on its own.
   procedure Test_Stem_And_Extension (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Files.Types;
      function Taken (Leaf : String) return Boolean is (Leaf = "draft.");
   begin
      Files_Suite.Support.Assert_Equal (Stem_Of ("notes.txt"), "notes", "a stem");
      Files_Suite.Support.Assert_Equal (Extension_Of ("notes.txt"), "txt", "an extension, without its dot");
      Files_Suite.Support.Assert_Equal (Stem_Of ("a.tar.gz"), "a.tar", "only the last dot splits");
      Files_Suite.Support.Assert_Equal (Stem_Of (".bashrc"), ".bashrc", "a leading dot is part of the name");
      Files_Suite.Support.Assert_Equal (Extension_Of (".bashrc"), "", "so there is no extension");
      Files_Suite.Support.Assert_Equal (Stem_Of ("draft."), "draft.", "nor after a trailing dot");
      Files_Suite.Support.Assert_Equal (Extension_Of ("draft."), "", "which is not an extension");
      Files_Suite.Support.Assert_Equal
        (Files.Paste.First_Free_Name ("draft.", Taken'Access), "draft. 2", "a numbered name keeps the trailing dot");
   end Test_Stem_And_Extension;
