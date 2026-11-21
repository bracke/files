separate (Files.File_System.Available_Root_Entries)
procedure Append_If_Directory
  (Path : String;
   Kind : Root_Kind)
is
   Full : Unbounded_String;
   Name : Unbounded_String;
   Label : Unbounded_String;
   Detail : Unbounded_String;
   Effective_Kind : Root_Kind := Kind;
begin
   if Natural (Roots.Length) >= Max_Discovered_Roots then
      return;
   end if;
   if Files.IO.Fs_Primitives.Directory_Exists (Path)
   then
      Full := To_Unbounded_String (Files.IO.Fs_Primitives.Full_Name (Path));
      Name := To_Unbounded_String (Files.Name_Parts.Leaf_Of (To_String (Full)));
      if Length (Name) = 0 then
         Name := Full;
      end if;
      if Kind in Root_Mount | Root_User_Mount | Root_Network_Mount | Root_Filesystem then
         declare
            Filesystem_Type : constant String := Filesystem_Type_For (To_String (Full));
         begin
            if Kind in Root_Mount | Root_User_Mount
              and then Is_Network_Filesystem_Type (Filesystem_Type)
            then
               Effective_Kind := Root_Network_Mount;
            end if;

            Label := To_Unbounded_String (Root_Label (To_String (Full), Effective_Kind));
            if Effective_Kind /= Root_Filesystem then
               Detail := To_Unbounded_String (Filesystem_Type);
            end if;
         end;
      else
         Label := To_Unbounded_String (Root_Label (To_String (Full), Effective_Kind));
      end if;
      if not Contains_Root (To_String (Full)) then
         Roots.Append
           (Root_Entry'
              (Path  => Full,
               Label => Label,
               Name  => To_Unbounded_String (Root_Name (To_String (Full), Effective_Kind)),
               Detail => Detail,
               Kind  => Effective_Kind,
               Volume_Name => Name,
               Removable => Effective_Kind = Root_Mount or else Effective_Kind = Root_User_Mount));
      end if;
   end if;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
end Append_If_Directory;
