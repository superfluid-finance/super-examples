// Produces properly formatted metadata json files with images in .resources/img/plant-stages.

fs = require('fs');
const { type } = require('os');
const path = require('path');

async function main() {

    // 1. Pin the plant-stages folder (see: resources/img/plant-stages) with your progressive flower images on Pinata 
    // 2. Paste the base link of the folder for the baseIpfs variable (replace below)
    const baseIpfs = "ipfs://Qmd4Sp9oSFMzFEuzwUQdihFMd3sYKQpoy4D8ckYd6bPVeC/"

    // Get array of image file names
    let fileNames = []
    fs.readdirSync("./resources/img/plant-stages").forEach(file => {
        fileNames.push( path.parse(file).name )
    });

    // generate metadata JSON file for each image file
    for (let i = 0; i < fileNames.length; i++) {
        const baseText = `
        {
            "name": "Evolving Flower NFT",
            "description": "Water an NFT with a Superfluid stream and watch it grow",
            "image": "${baseIpfs}${fileNames[i]}.png"
        }`

        fs.writeFile(`./resources/flower-metadatas/${fileNames[i]}.json`,baseText, function (err) {
            if (err) return console.log("Make sure you run this in the base of the repo");
        });
    };

    // This will fill the flower-metadatas folder which you'll want to pin on Pinata
}

main();