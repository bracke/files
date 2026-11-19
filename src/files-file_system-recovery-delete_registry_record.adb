separate (Files.File_System.Recovery)
   procedure Delete_Registry_Record (Directory : String) is
      Root : constant String := Registry_Root (Create => False);
      Hold : Registry_Hold;
      Count : Natural := 0;
      Other : Boolean := False;

      procedure Check (Name : String; Stop : in out Boolean) is
      begin
         if Name = "record" then
            Count := Count + 1;
         else
            Other := True;
            Stop := True;
         end if;
      end Check;
   begin
      if Root = ""
        or else Files.Fs_Primitives.Parent_Directory (Directory) /= Root
        or else not Files.Types.Starts_With
                      (Files.Types.Leaf_Of (Directory), Files.Protocol_Names.Recovery_Stage_Prefix)
        or else Hostkit.Fs.Is_Link (Directory)
      then
         return;
      end if;
      Hold_Registry (Root, Hold);
      Files.Fs_Primitives.For_Each_Name (Directory, Check'Access);
      if Count = 1 and then not Other then
         Delete_Owned_Tree (Directory);
      end if;
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.File_System.Recovery");
   end Delete_Registry_Record;
