separate (Files.Operations.Compress_Selected)
procedure Collect
  (Full       : String;
   Entry_Name : String;
   Depth      : Natural := 0)
is
   procedure Visit (Name : String; Kind : Hostkit.Fs.Entry_Kind; Stop : in out Boolean) is
      use type Hostkit.Fs.Entry_Kind;
   begin
      if Collection_Failed then
         Stop := True;
      elsif Files.Jobs.Context.Cancelled then
         --  A cancel fails the collection: nothing collected is compressed.
         Collection_Failed := True;
         Stop := True;
      elsif Kind in Hostkit.Fs.Ordinary_File_Entry | Hostkit.Fs.Directory_Entry then
         Collect (Hostkit.Fs.Join (Full, Name), Entry_Name & "/" & Name, Depth + 1);
      end if;
   end Visit;
begin
   if Files.Jobs.Context.Cancelled then
      Collection_Failed := True;
      return;
   elsif Depth > Max_Archive_Depth
     or else Natural (Input_Paths.Length) >= Max_Archive_Entries
   then
      Collection_Failed := True;
      return;
   --  refusal-safe: a refused lookup fails the collection
   elsif not Files.IO.Fs_Primitives.Entry_Exists (Full) then
      Collection_Failed := True;
      return;
   elsif Hostkit.Fs.Is_Link (Full) then
      --  Skip symlinks instead of following them: Ada.Directories.Kind
      --  dereferences a link, so a link to an ancestor would recurse
      --  unbounded (Storage_Error) and a link to a directory would archive
      --  the target's contents under the link's name. The archive
      --  writers cannot store a link, so say it was left out.
      Links_Skipped := Links_Skipped + 1;
      return;
   elsif Files.IO.Fs_Primitives.Kind (Full) = Ada.Directories.Directory then
      if not Record_Entry (Full, Entry_Name) then
         Collection_Failed := True;
         return;
      end if;
      Files.IO.Fs_Primitives.For_Each_Listed (Full, Visit'Access);
   elsif Files.IO.Fs_Primitives.Kind (Full) = Ada.Directories.Ordinary_File then
      if not Record_Entry (Full, Entry_Name) then
         Collection_Failed := True;
      end if;
   end if;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      Collection_Failed := True;
end Collect;
