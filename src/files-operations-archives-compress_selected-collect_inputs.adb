separate (Files.Operations.Archives.Compress_Selected)
function Collect_Inputs return Collect_Outcome is
   Top_Names : Archive_Name_Sets.Set;

   --  An archive entry's name is bounded only by the format's 16-bit
   --  name field, not by a volume.
   Entry_Limit : constant Hostkit.Fs.Leaf_Name_Limit := (Unit => Hostkit.Fs.Bytes, Most => 65_535);

   function Taken (Name : String) return Boolean is (Top_Names.Contains (Files.Text_Case.Fold_Case (Name)));

   --  The numbering a paste gives a name in use: "readme 2.txt", a plain
   --  folder's dots kept in its name.
   function Entry_For (Name : String; Is_Folder : Boolean) return String is
      Free : constant String :=
        Files.Leaf_Names.First_Free
          (Files.Name_Parts.Name_Stem (Name, Is_Folder), Files.Name_Parts.Name_Extension (Name, Is_Folder),
           Files.Leaf_Names.Spaced_Number'Access, Taken'Access, Entry_Limit);
   begin
      return (if Free = "" then Name else Free);
   end Entry_For;
begin
   for Item of Items loop
      declare
         Name : constant String :=
           Entry_For (To_String (Item.Name), Item.Kind = Files.Types.Directory_Item);
      begin
         Top_Names.Include (Files.Text_Case.Fold_Case (Name));
         Collect (To_String (Item.Full_Path), Name);
      end;
   end loop;

   if Collection_Failed or else Input_Paths.Is_Empty then
      return Collection_Error;
   end if;
   --  Both writers refuse such names; the caller says why rather than
   --  failing the archive with the generic error.
   for Name of Entry_Names loop
      if not Files.Operations.Archive_Writing.Portable_Entry_Name (To_String (Name)) then
         return Unportable_Name;
      end if;
   end loop;
   return Collected;
end Collect_Inputs;
