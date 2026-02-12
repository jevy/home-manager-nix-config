import trianglify from 'trianglify';
import { writeFileSync } from 'fs';

const [,, output, width, height, seed, cellSize] = process.argv;

const pattern = trianglify({
  width: +width || 3840,
  height: +height || 2160,
  seed: seed || 'gruvbox42',
  cellSize: +cellSize || 75,
  variance: 0.75,
  xColors: ['#32302f', '#d8a657', '#e78a4e', '#ea6962', '#45403d'],
  yColors: ['#32302f', '#7daea3', '#a9b665', '#d3869b', '#45403d'],
});

writeFileSync(output, pattern.toSVG().toString());
