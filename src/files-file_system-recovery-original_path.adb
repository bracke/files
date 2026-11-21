separate (Files.File_System.Recovery)
   function Original_Path (Path : String) return String is
      Target : UString;
      Identity : UString;
      Record_Path : constant String :=
        Hostkit.Fs.Join (Files.Fs_Primitives.Parent_Directory (Path), "original");
   begin
      if Read_Owner (Files.Fs_Primitives.Parent_Directory (Path), Target, Identity) then
         return To_String (Target);
      end if;
      if not Record_Is_Regular (Record_Path, Original_Record_Bytes) then
         return "";
      end if;
      Target := Read_Original_File (Record_Path, Header => "", Max_Bytes => Original_Record_Bytes);
      return
        (if Valid_Absolute_Path (To_String (Target)) then
            To_String (Target)
         else "");
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         return "";
   end Original_Path;
