"""Regenerates lib/data/campus_building_shapes.dart.

Shapes are the surveyed roof surfaces in Montreal's 3D building model (LOD2,
2013 edition, CC BY 4.0, Ville de Montreal). Roofs at the same level are merged
and stacked, and sloped roofs become short steps. Two other sources:

* OpenStreetMap (ODbL) outlines say where one building ends and the next
  begins, and which of the basemap's own buildings to remove.
* Natural Resources Canada's HRDEM Mosaic 1 m laser scan (Open Government
  Licence - Canada) gives ground level and checks the result.

    python3 -m venv /tmp/shapes
    /tmp/shapes/bin/pip install rasterio shapely lxml
    /tmp/shapes/bin/python tool/build_campus_shapes.py

Downloads about 65 MB the first time, into a cache in the temp folder.
"""
import json
import pathlib
import re
import subprocess
import tempfile
import zlib

import numpy as np
import rasterio
from lxml import etree
from rasterio.features import geometry_mask
from rasterio.warp import transform_bounds, transform_geom
from rasterio.windows import from_bounds
from shapely.geometry import Polygon, mapping, shape
from shapely.ops import unary_union
from shapely.strtree import STRtree

# OpenStreetMap ways. Keys match CampusBuilding.id in campus_buildings.dart.
WAYS = {
    'university-centre': 30176564,
    'mcconnell': 112977926,
    'leacock': 19912994,
    'burnside': 20168777,
    'bronfman': 20169169,
    'education': 46867137,
    'strathcona-music': 80263147,
    'chancellor-day': 340258402,
    'adams': 112976640,
    'macdonald-harrington': 20168782,
    'macdonald-engineering': 20168784,
    'trottier': 21341557,
    'wong': 21340760,
    'rutherford': 21341559,
    'thomson-house': 165265063,
}
BOUNDS = (-73.5865, 45.4995, -73.5685, 45.5115)
# Tiles of the city model that contain campus.
TILES = ['VM12', 'VM08', 'VM11', 'VM18', 'PMR01']
MTM8 = 'EPSG:32188'  # Metres.
SLOPE_STEP = 1.5  # Height of the steps that stand in for a sloped roof.
MERGE = 1.3  # Roofs closer in height than this become one level.

CACHE = pathlib.Path(tempfile.gettempdir()) / 'campus-shapes'
OUT = pathlib.Path(__file__).parent.parent / 'lib/data/campus_building_shapes.dart'
# curl, because the Python that ships with macOS has outdated TLS.
CURL = ['curl', '-sS', '--fail', '-L', '--retry', '6', '--retry-delay', '8',
        '--retry-all-errors', '-m', '200', '-A', 'campus-footprint-tool/1.0']


def curl(url, *extra):
    return subprocess.run(CURL + list(extra) + [url], check=True,
                          capture_output=True).stdout


def cached(name, make):
    path = CACHE / name
    if not path.exists():
        CACHE.mkdir(exist_ok=True)
        path.write_bytes(make())
    return path


def polygons(geometry):
    parts = geometry.geoms if hasattr(geometry, 'geoms') else [geometry]
    return [p for p in parts if isinstance(p, Polygon) and not p.is_empty]


# --- Sources ---------------------------------------------------------------

def osm_buildings():
    south, west, north, east = BOUNDS[1], BOUNDS[0], BOUNDS[3], BOUNDS[2]
    query = '[out:json][timeout:60];way["building"](%s,%s,%s,%s);out geom;' % (
        south, west, north, east)
    path = cached('osm.json', lambda: curl(
        'https://overpass-api.de/api/interpreter', '--data-urlencode', 'data=' + query))
    found = {}
    for way in json.loads(path.read_bytes())['elements']:
        ring = [(p['lon'], p['lat']) for p in way.get('geometry', [])]
        if len(ring) > 3 and 'building:part' not in way['tags']:
            outline = {'type': 'Polygon', 'coordinates': [ring]}
            found[way['id']] = shape(transform_geom('EPSG:4326', MTM8, outline)).buffer(0)
    # A tower mapped separately inside a building belongs to it.
    inside = {}
    for key, way in WAYS.items():
        for other, outline in list(found.items()):
            if other not in WAYS.values() and outline.area and (
                    outline.intersection(found[way]).area > 0.6 * outline.area):
                inside.setdefault(key, {})[other] = found.pop(other)
    return found, inside


def tile_geometry(tile, urls):
    """Just the geometry file from a tile, skipping its hundreds of photos."""
    def read(url, start, length):
        return curl(url, '-r', '%d-%d' % (start, start + length - 1))

    def make():
        url = urls[tile]
        headers = subprocess.run(CURL + ['-I', url], capture_output=True, text=True).stdout
        size = int(re.findall(r'(?i)content-length: *(\d+)', headers)[-1])
        tail = read(url, size - 4096, 4096)
        end = tail.rindex(b'PK\x05\x06')
        length = int.from_bytes(tail[end + 12:end + 16], 'little')
        start = int.from_bytes(tail[end + 16:end + 20], 'little')
        directory, at = read(url, start, length), 0
        while directory[at:at + 4] == b'PK\x01\x02':
            packed = int.from_bytes(directory[at + 20:at + 24], 'little')
            sizes = [int.from_bytes(directory[at + i:at + i + 2], 'little')
                     for i in (28, 30, 32)]
            offset = int.from_bytes(directory[at + 42:at + 46], 'little')
            if directory[at + 46:at + 46 + sizes[0]].lower().endswith(b'.gml'):
                head = read(url, offset, 30)
                skip = 30 + sum(int.from_bytes(head[i:i + 2], 'little') for i in (26, 28))
                return zlib.decompress(read(url, offset + skip, packed), -15)
            at += 46 + sum(sizes)
        raise ValueError('no geometry in ' + tile)
    return cached(tile + '.gml', make)


def city_roofs(near):
    catalogue = json.loads(cached('catalogue.json', lambda: curl(
        'https://www.donneesquebec.ca/recherche/api/3/action/package_show?id='
        'vmtl-maquette-numerique-plateau-mont-royal-batiments-lod2-avec-textures'
    )).read_bytes())
    urls = {r['name'].split()[1].split('_')[0]: r['url']
            for r in catalogue['result']['resources'] if r['format'] == 'GML'}
    gml = '{http://www.opengis.net/gml}'
    bldg = '{http://www.opengis.net/citygml/building/1.0}'
    for tile in TILES:
        path = str(tile_geometry(tile, urls))
        for _, building in etree.iterparse(path, tag=bldg + 'Building', huge_tree=True):
            for surface in building.iter(bldg + 'RoofSurface'):
                for polygon in surface.iter(gml + 'Polygon'):
                    rings = []
                    for ring in polygon.iter(gml + 'LinearRing'):
                        listed = ring.find(gml + 'posList')
                        text = listed.text.split() if listed is not None else [
                            n for p in ring.findall(gml + 'pos') for n in p.text.split()]
                        rings.append(np.array(text, float).reshape(-1, 3))
                    if rings and len(rings[0]) >= 4:
                        low, high = rings[0].min(0), rings[0].max(0)
                        if any(low[0] < b[2] and high[0] > b[0] and
                               low[1] < b[3] and high[1] > b[1] for b in near):
                            yield rings
            building.clear()
            while building.getprevious() is not None:
                del building.getparent()[0]


class Lidar:
    def __init__(self):
        item = json.loads(curl(
            'https://datacube.services.geo.ca/stac/api/search?collections='
            'hrdem-mosaic-1m&limit=1&bbox=' + ','.join(map(str, BOUNDS))))['features'][0]
        self.layers = {}
        for name in ('dsm', 'dtm'):
            with rasterio.open('/vsicurl/' + item['assets'][name]['href']) as r:
                box = transform_bounds('EPSG:4326', r.crs, *BOUNDS)
                window = from_bounds(*box, r.transform).round_offsets().round_lengths()
                grid = r.read(1, window=window).astype(float)
                grid[grid == r.nodata] = np.nan
                self.layers[name] = grid
                self.transform, self.crs = r.window_transform(window), r.crs

    def mask(self, geometry):
        moved = transform_geom(MTM8, self.crs, mapping(geometry))
        return ~geometry_mask([moved], self.layers['dsm'].shape, self.transform)

    def sample(self, layer, geometry):
        values = self.layers[layer][self.mask(geometry)]
        return values[~np.isnan(values)]


# --- Shapes ----------------------------------------------------------------

def level_pieces(rings):
    """A roof surface as flat pieces: itself, or steps if it slopes."""
    points = rings[0]
    flat = Polygon(points[:, :2], [r[:, :2] for r in rings[1:] if len(r) >= 4]).buffer(0)
    if flat.area < 0.05:
        return
    low, high = points[:, 2].min(), points[:, 2].max()
    if high - low <= 0.7:
        for part in polygons(flat):
            yield part, float(points[:-1, 2].mean())
        return
    middle = points[:-1, :2].mean(0)
    matrix = np.c_[points[:-1, :2] - middle, np.ones(len(points) - 1)]
    (a, b, c), *_ = np.linalg.lstsq(matrix, points[:-1, 2], rcond=None)
    slope = np.hypot(a, b)
    if slope < 1e-6 or slope > 6:
        for part in polygons(flat):
            yield part, float((low + high) / 2)
        return
    ux, uy, far = a / slope, b / slope, 1e4
    for k in range(int(np.floor(low / SLOPE_STEP)), int(np.ceil(high / SLOPE_STEP))):
        near = (max(low, k * SLOPE_STEP) - c) / slope
        away = (min(high, (k + 1) * SLOPE_STEP) - c) / slope
        band = Polygon([
            (middle[0] + ux * d - uy * s, middle[1] + uy * d + ux * s)
            for d, s in ((near, far), (near, -far), (away, -far), (away, far))])
        height = (k + 0.5) * SLOPE_STEP if high - low > SLOPE_STEP else (low + high) / 2
        for part in polygons(flat.intersection(band)):
            if part.area > 0.02:
                yield part, float(height)


def assign(surfaces, outlines):
    """Shares attached buildings' roofs out between them."""
    ids = list(outlines)
    tree = STRtree([outlines[i] for i in ids])
    keys = {way: key for key, way in WAYS.items()}
    roofs = {key: [] for key in WAYS}
    for rings in surfaces:
        for piece, z in level_pieces(rings):
            near = sorted(((outlines[i].intersection(piece).area / piece.area,
                            -outlines[i].distance(piece), i)
                           for i in (ids[n] for n in tree.query(piece.buffer(3)))),
                          reverse=True)
            if not near:
                continue
            share, distance, best = near[0]
            if share >= 0.7 or len(near) < 2 or near[1][0] < 0.08:
                if (share >= 0.05 or -distance <= 2.5) and best in keys:
                    roofs[keys[best]].append((piece, z))
                continue
            rest = piece
            for _, _, way in near:
                part = rest.intersection(outlines[way].buffer(0.6))
                rest = rest.difference(outlines[way].buffer(0.6))
                if way in keys:
                    roofs[keys[way]] += [(p, z) for p in polygons(part) if p.area > 0.3]
    return roofs


def tidy(geometry, smallest=8, hole=6):
    return unary_union([
        Polygon(p.exterior, [h for h in p.interiors if Polygon(h).area > hole])
        for p in polygons(geometry) if p.area >= smallest])


def stack(pieces, shift):
    """Merged roof levels, each inside the one below: [(shape, base, top)]."""
    footprint = tidy(
        unary_union([g.buffer(0.15) for g, _ in pieces]).buffer(-0.15), smallest=25)
    groups = []
    for height, piece in sorted(((max(2.0, z + shift), g) for g, z in pieces),
                                key=lambda item: item[0]):
        if groups and height - groups[-1]['z'] <= MERGE:
            group = groups[-1]
            total = group['area'] + piece.area
            group['z'] = (group['z'] * group['area'] + height * piece.area) / total
            group['area'] = total
            group['pieces'].append(piece)
        else:
            groups.append({'z': height, 'area': piece.area, 'pieces': [piece]})
    while len(groups) > 1 and groups[0]['area'] < 12:
        groups[1]['pieces'] += groups.pop(0)['pieces']
    result = [(footprint, 0.0, groups[0]['z'])]
    for i in range(1, len(groups)):
        below, base, top = result[-1]
        level = unary_union([
            p.buffer(0.12) for g in groups[i:] for p in g['pieces']]).buffer(-0.12)
        # Ledges too thin to see become part of the wall.
        ledge = below.difference(level.intersection(below))
        ledge = ledge.buffer(-0.35, join_style=2).buffer(0.36, join_style=2)
        level = tidy(below.difference(ledge))
        level = level.buffer(-0.4, join_style=2).buffer(0.4, join_style=2)
        level = tidy(level.intersection(below))
        if level.is_empty:
            break
        if below.area - level.area < 8:
            result[-1] = (below, base, groups[i]['z'])
        else:
            result.append((level, top, groups[i]['z']))
    return [(tidy(g.simplify(0.18)).buffer(0), b, t) for g, b, t in result]


def degrees(polygon):
    moved = transform_geom(MTM8, 'EPSG:4326', mapping(polygon), precision=6)
    return [[list(point) for point in ring] for ring in moved['coordinates']]


def main():
    outlines, inside = osm_buildings()
    near = [outlines[way].buffer(4).bounds for way in WAYS.values()]
    roofs = assign(city_roofs(near), outlines)
    lidar = Lidar()
    # The two surveys use different zero levels: compare big flat roofs.
    offsets = []
    for pieces in roofs.values():
        for piece, z in pieces:
            if piece.area > 120:
                scan = lidar.sample('dsm', piece.buffer(-2))
                if len(scan) > 40 and scan.std() < 1.2:
                    offsets.append(np.median(scan) - z)
    offset = float(np.median(offsets))
    print('survey offset %.2f m from %d roofs' % (offset, len(offsets)))

    lines = []
    for key, way in WAYS.items():
        footprint = unary_union([g.buffer(0.15) for g, _ in roofs[key]])
        around = footprint.buffer(5).difference(footprint.buffer(1.5))
        ground = float(np.median(lidar.sample('dtm', around)))
        tiers = stack(roofs[key], offset - ground)
        footprint = tiers[0][0]

        model = np.zeros(lidar.layers['dsm'].shape)
        for geometry, _, top in tiers:
            if not geometry.is_empty:
                model[lidar.mask(geometry)] = top
        here = lidar.mask(footprint.buffer(-1))
        error = np.abs((lidar.layers['dsm'] - ground - model)[here])
        overlap = footprint.intersection(outlines[way]).area / outlines[way].area
        print('%-22s %2d levels, %3d corners, off by %.1f m (median), overlaps OSM %d%%' % (
            key, len(tiers),
            sum(len(r.coords) - 1 for g, _, _ in tiers for p in polygons(g)
                for r in [p.exterior, *p.interiors]),
            np.nanmedian(error), overlap * 100))

        middle = transform_geom(MTM8, 'EPSG:4326', mapping(
            max(polygons(tiers[-1][0] if tiers[-1][0].area > 150 else footprint),
                key=lambda p: p.area).representative_point()), precision=6)
        # Kept inside the outline, so no neighbour is removed with it.
        extra = inside.get(key, {})
        basemap = unary_union([outlines[way], *extra.values()]).buffer(-1)
        lines.append(json.dumps({
            'id': key,
            'osm': [way, *extra],
            'center': list(middle['coordinates']),
            'parts': [
                {'base': round(base, 1), 'top': round(top, 1), 'rings': degrees(p)}
                for geometry, base, top in tiers for p in polygons(geometry)],
            'outline': [degrees(p) for p in polygons(footprint)],
            'basemap': [degrees(p) for p in polygons(basemap)],
        }, separators=(',', ':')))
    OUT.write_text(
        '// GENERATED by tool/build_campus_shapes.py. One building per line.\n'
        '// Shapes: Ville de Montreal 3D buildings, CC BY 4.0. Building divisions:\n'
        '// (c) OpenStreetMap contributors, ODbL. Ground level: HRDEM Mosaic, Natural\n'
        '// Resources Canada, Open Government Licence - Canada.\n'
        "const campusBuildingShapeRows = r'''\n" + '\n'.join(lines) + "\n''';\n")


main()
