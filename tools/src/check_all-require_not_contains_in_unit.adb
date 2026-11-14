separate (Check_All)
   procedure Require_Not_Contains_In_Unit
     (Base_Path : String;
      Pattern   : String;
      Message   : String)
   is
      Dir  : constant String := Ada.Directories.Containing_Directory (Base_Path);
      Stem : constant String := Ada.Directories.Base_Name (Base_Path);
   begin
      Require_Not_Contains (Base_Path, Pattern, Message);

      --  Only a body has subunits; a spec (.ads) is covered on its own.
      if Ada.Directories.Extension (Base_Path) /= "adb" then
         return;
      end if;

      --  Its subunits: the sibling bodies <stem>-*.adb.
      for Subunit of Project_Tools.Files.List_Tree (Dir, Stem & "-?*.adb", Generated_Directories) loop
         Require_Not_Contains (To_String (Subunit), Pattern, Message);
      end loop;
   end Require_Not_Contains_In_Unit;
