"""Read-only polygon boundary loops; candidates require visual/physics checks."""
from collections import Counter, defaultdict
import struct
import sys
from inspect_data import bsa

models = bsa('ARCH3D.BSA')
for name in sys.argv[1:]:
    data = models[name]
    start = struct.unpack_from('<I', data, 48)[0]
    face = struct.unpack_from('<I', data, 60)[0]
    edges = Counter()
    for i in range(struct.unpack_from('<I', data, 8)[0]):
        count = data[face]
        points = []
        for j in range(count):
            pointer = struct.unpack_from('<I', data, face + 8 + j * 8)[0]
            if data[:4] == b'v2.5':
                pointer *= 3
            points.append(tuple(v / 256 for v in struct.unpack_from('<iii', data, start + pointer)))
        face += 8 + count * 8
        for j in range(count):
            edges[tuple(sorted((points[j], points[(j + 1) % count])))] += 1
    graph = defaultdict(set)
    for (a, b), count in edges.items():
        if count == 1:
            graph[a].add(b)
            graph[b].add(a)
    print('MODEL', name)
    seen = set()
    for first in graph:
        if first in seen:
            continue
        pending = [first]
        points = []
        while pending:
            point = pending.pop()
            if point in seen:
                continue
            seen.add(point)
            points.append(point)
            pending.extend(graph[point] - seen)
        print('  boundary', len(points), [min(p[c] for p in points) for c in range(3)], [max(p[c] for p in points) for c in range(3)])
