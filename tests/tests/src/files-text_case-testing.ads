--  Test-only conveniences over Files.Text_Case, kept out of the program.
package Files.Text_Case.Testing is

   --  Whether Needle occurs in Haystack after case folding: the filter's
   --  match (Contains_Folded) with the needle folded here.
   --
   --  @param Haystack Text to search.
   --  @param Needle Text to find.
   --  @return True when Needle occurs in Haystack case-insensitively.
   function Contains_Case_Insensitive
     (Haystack : String;
      Needle   : String)
      return Boolean is
     (Contains_Folded (Haystack, Fold_Case (Needle)));

end Files.Text_Case.Testing;
