separate (Files.Model)
   function Rename_Behavior return Rename_Policy is
   begin
      return
        (Single_Item_Only       => False,
         Synchronized_Multi     => True,
         Atomic_Multi_Rename    => False,
         Requires_One_Selection => False);
   end Rename_Behavior;
