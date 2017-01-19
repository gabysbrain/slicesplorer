
from glob import iglob
from os.path import basename
import re

from compute_stats import convert_slices
from cluster_slices import identify_clusters
from slice_neighbors import slice_neighbors

def slice_list():
  curname = None
  dimlist = []
  for fname in sorted(iglob("slice_samples/*_*_slices.csv")):
    m = re.match(r"(.*?)_([0-9]*?)_slices\.csv", basename(fname))
    group_name = m.group(1)
    dims = int(m.group(2))
    if curname != group_name:
      dimlist.sort()
      if curname != None: yield (curname, dimlist)
      curname = group_name
      dimlist = []
    dimlist.append(dims)
  dimlist.sort()
  if curname != None:
    yield (curname, dimlist)

def get(function, dims):
  s = convert_slices(function, dims)
  s = identify_clusters(s)
  s = slice_neighbors(s)
  return s

if __name__ == '__main__':
  print(list(slice_list()))

